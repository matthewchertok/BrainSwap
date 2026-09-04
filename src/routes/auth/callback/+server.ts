import { redirect } from '@sveltejs/kit';
import { sendAccessRequestEmail, verifiedPrimaryGoogleEmail } from '$lib/server/access-request-email';
import { safeReturnPath } from '$lib/validation';

async function endSession(locals: App.Locals) {
  const { error } = await locals.supabase.auth.signOut();
  if (error) await locals.supabase.auth.signOut({ scope: 'local' });
}

export const GET = async ({ url, locals }) => {
  const code = url.searchParams.get('code');
  if (!code) redirect(303, '/login?error=missing_code');
  const { error } = await locals.supabase.auth.exchangeCodeForSession(code);
  if (error) redirect(303, '/login?error=oauth_exchange');
  const { data, error: claimError } = await locals.supabase.rpc('claim_available_memberships');
  if (claimError) {
    await endSession(locals);
    redirect(303, '/login?error=membership_check');
  }
  if (data?.length) redirect(303, safeReturnPath(url.searchParams.get('next')));

  let requestStatus: 'sent' | 'failed' = 'failed';
  if (url.searchParams.get('intent') === 'request_access') {
    const { data: authData, error: userError } = await locals.supabase.auth.getUser();
    const authUser = userError ? null : authData.user;
    const requesterEmail = verifiedPrimaryGoogleEmail(authUser);
    if (requesterEmail && authUser) {
      const delivery = await sendAccessRequestEmail(requesterEmail, authUser.id);
      requestStatus = delivery === 'sent' ? 'sent' : 'failed';
    }
  }

  if (url.searchParams.get('intent') === 'request_access') {
    await endSession(locals);
    redirect(303, `/unauthorized?request=${requestStatus}`);
  }
  redirect(303, '/unauthorized');
};
