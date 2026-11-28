// Shared helpers for the admin Edge Functions.
// The service role key is only available here (Supabase sets SUPABASE_SERVICE_ROLE_KEY for
// every Edge Function). It is never shipped in the Flutter app.
import { createClient, type SupabaseClient, type User } from 'npm:@supabase/supabase-js@2';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export interface AdminContext {
  /** Service-role client: bypasses RLS, can call auth.admin.*. */
  service: SupabaseClient;
  /** Client acting as the calling admin (RLS and private.is_admin() apply). */
  asCaller: SupabaseClient;
  caller: User;
}

/** Same columns the app reads in SupabaseBackend (_accountSelect). */
export const accountSelect =
  'user_id, email, full_name, phone, active, role_id, created_at, roles(role_name), ' +
  'motorcycle_owners(notification_enabled), mechanics(workshop_id, workshops(*)), admins(staff_code)';

/** Returns the context when the request comes from an active Admin, otherwise an error response. */
export async function requireAdmin(req: Request): Promise<AdminContext | Response> {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !serviceKey || !anonKey) return json({ error: 'The function is not configured.' }, 500);

  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return json({ error: 'Log in first.' }, 401);

  const service = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: auth, error: authError } = await service.auth.getUser(token);
  if (authError || !auth?.user) return json({ error: 'Your session has expired. Log in again.' }, 401);

  const { data: row, error } = await service
    .from('user_accounts')
    .select('active, roles(role_name)')
    .eq('user_id', auth.user.id)
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  const roleName = (row as any)?.roles?.role_name;
  if (error || !row || !row.active || roleName !== 'admin') {
    return json({ error: 'Only admins can manage user accounts.' }, 403);
  }

  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { service, asCaller, caller: auth.user };
}
