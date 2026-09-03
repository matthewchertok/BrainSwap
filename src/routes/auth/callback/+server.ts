import { redirect } from '@sveltejs/kit';
import { safeReturnPath } from '$lib/validation';
export const GET = async ({ url, locals }) => {
  const code = url.searchParams.get('code');
  if (!code) redirect(303, '/login?error=missing_code');
  const { error } = await locals.supabase.auth.exchangeCodeForSession(code);
  if (error) redirect(303, '/login?error=oauth_exchange');
  const { data, error: claimError } = await locals.supabase.rpc('claim_available_memberships');
  if (claimError || !data?.length) {
    const { error: signOutError } = await locals.supabase.auth.signOut();
    if (signOutError) await locals.supabase.auth.signOut({ scope: 'local' });
    redirect(303, '/unauthorized');
  }
  redirect(303, safeReturnPath(url.searchParams.get('next')));
};
