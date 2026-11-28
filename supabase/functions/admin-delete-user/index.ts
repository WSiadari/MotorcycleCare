// Deletes a user account (admins only).
// POST { user_id } → 200 { deleted: user_id }
// Deleting the Supabase Auth user cascades to user_accounts and everything that belongs to it
// (motorcycle_owners → motorcycles → readings, records, reminders; mechanics → jobs, reviews).
// Records the user saved for other people's motorcycles stay, with recorded_by_user_id = null.
//
// Deploy: supabase functions deploy admin-delete-user
import { corsHeaders, json, requireAdmin } from '../_shared/admin.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Use POST.' }, 405);

  const ctx = await requireAdmin(req);
  if (ctx instanceof Response) return ctx;

  // deno-lint-ignore no-explicit-any
  const body: any = await req.json().catch(() => ({}));
  const userId = String(body.user_id ?? '');
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return json({ error: 'Unknown user.' }, 400);
  if (userId === ctx.caller.id) return json({ error: "You can't delete your own account." }, 400);

  const { error } = await ctx.service.auth.admin.deleteUser(userId);
  if (error) return json({ error: error.message }, 400);
  return json({ deleted: userId });
});
