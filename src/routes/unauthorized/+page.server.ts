import { fail, redirect } from '@sveltejs/kit';
import {
  accessRequestEmailSettings,
  sendAccessRequestEmail,
  verifiedPrimaryGoogleEmail
} from '$lib/server/access-request-email';
import type { Actions, PageServerLoad } from './$types';

async function endSession(locals: App.Locals) {
  const { error } = await locals.supabase.auth.signOut();
  if (error) await locals.supabase.auth.signOut({ scope: 'local' });
}

export const load: PageServerLoad = ({ url, locals }) => {
  const request = url.searchParams.get('request');
  return {
    request: request === 'sent' || request === 'failed' ? request : null,
    canRequestAccess: Boolean(locals.userId) && accessRequestEmailSettings() !== null
  };
};

export const actions: Actions = {
  requestAccess: async ({ locals }) => {
    if (!accessRequestEmailSettings())
      return fail(503, { message: 'Access requests are temporarily unavailable. Please try again later.' });

    const { data, error } = await locals.supabase.auth.getUser();
    const requesterEmail = error ? null : verifiedPrimaryGoogleEmail(data.user);
    if (!requesterEmail)
      return fail(401, {
        message: 'Your Google session could not be verified. Please return to sign in and try again.'
      });

    const delivery = await sendAccessRequestEmail(requesterEmail);
    if (delivery !== 'sent') return fail(502, { message: 'Your access request could not be sent. Please try again.' });

    await endSession(locals);
    redirect(303, '/unauthorized?request=sent');
  }
};
