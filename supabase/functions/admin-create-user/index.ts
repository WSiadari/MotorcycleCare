// Creates a user account (admins only).
// POST { full_name, email, password, role: 'owner'|'mechanic'|'admin', workshop_name?, phone? }
// → 201 { user: <user_accounts row with role + subtype> }
//
// 1. checks that the caller is an active Admin (service role lookup)
// 2. creates the Supabase Auth user (email already confirmed); the on_auth_user_created
//    trigger adds user_accounts + motorcycle_owners
// 3. for Mechanic/Admin calls public.admin_update_user AS THE CALLER, so the role change
//    goes through the same server checks as editing a user in the app
// 4. if step 3 fails the new auth user is removed again
//
// Deploy: supabase functions deploy admin-create-user
import { accountSelect, corsHeaders, json, requireAdmin } from '../_shared/admin.ts';

const roles = ['owner', 'mechanic', 'admin'];
const emailRe = /^[\w.+-]+@[\w-]+(\.[\w-]+)+$/;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Use POST.' }, 405);

  const ctx = await requireAdmin(req);
  if (ctx instanceof Response) return ctx;

  // deno-lint-ignore no-explicit-any
  const body: any = await req.json().catch(() => ({}));
  const fullName = String(body.full_name ?? '').trim();
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');
  const role = String(body.role ?? '');
  const workshopName = String(body.workshop_name ?? '').trim();
  const phone = String(body.phone ?? '').trim();

  if (fullName.length < 3) return json({ error: 'Enter the full name.' }, 400);
  if (!emailRe.test(email)) return json({ error: 'Enter a valid email, e.g. name@email.com.' }, 400);
  if (password.length < 8) return json({ error: 'Use at least 8 characters for the password.' }, 400);
  if (!roles.includes(role)) return json({ error: 'Choose a role to continue.' }, 400);
  if (role === 'mechanic' && !workshopName) return json({ error: 'Enter the workshop name.' }, 400);

  const { data: created, error: createError } = await ctx.service.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createError || !created?.user) {
    const message = createError?.message ?? 'The account could not be created.';
    if (/already (been )?registered|already exists/i.test(message)) {
      return json({ error: 'This email is already registered. Use another email.' }, 409);
    }
    return json({ error: message }, 400);
  }
  const userId = created.user.id;

  const { error: roleError } = await ctx.asCaller.rpc('admin_update_user', {
    p_user_id: userId,
    p_full_name: fullName,
    p_phone: phone || null,
    p_role: role,
    p_active: true,
    p_workshop_name: role === 'mechanic' ? workshopName : null,
  });
  if (roleError) {
    await ctx.service.auth.admin.deleteUser(userId);
    return json({ error: roleError.message }, 400);
  }

  const { data: account, error: readError } = await ctx.service
    .from('user_accounts')
    .select(accountSelect)
    .eq('user_id', userId)
    .single();
  if (readError) return json({ error: readError.message }, 500);
  return json({ user: account }, 201);
});
