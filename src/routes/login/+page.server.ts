import { fail, redirect } from '@sveltejs/kit';
import { accessRequestEmailSettings } from '$lib/server/access-request-email';
import { safeReturnPath } from '$lib/validation';
import type { Actions, PageServerLoad } from './$types';

const authMessages: Record<string, string> = {
  missing_code: 'Google did not return a sign-in code. Please try again.',
  oauth_exchange: 'Google sign-in could not be completed. Please try again.',
  membership_check: 'Membership could not be checked. Please try again later.',
  signout: 'You were signed out locally, but global session revocation could not be confirmed. Please try again later.',
  signout_failed:
    "Sign-out could not be confirmed. Clear this site's browser data, close the browser, and contact the lab operator."
};

export const load: PageServerLoad = ({ url }) => ({
  message: authMessages[url.searchParams.get('error') ?? ''] ?? null,
  next: safeReturnPath(url.searchParams.get('next')),
  accessRequestsEnabled: accessRequestEmailSettings() !== null
});

async function startGoogleOAuth(
  locals: App.Locals,
  origin: string,
  next: FormDataEntryValue | null,
  intent: 'sign_in' | 'request_access'
) {
  if (intent === 'request_access' && !accessRequestEmailSettings())
    return fail(503, { message: 'Access requests are temporarily unavailable. Please try again later.' });

  const callback = new URL('/auth/callback', origin);
  callback.searchParams.set('next', safeReturnPath(typeof next === 'string' ? next : null));
  if (intent === 'request_access') callback.searchParams.set('intent', intent);

  const { data, error } = await locals.supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: callback.toString(),
      skipBrowserRedirect: true,
      scopes: 'openid email profile',
      queryParams: intent === 'request_access' ? { prompt: 'select_account' } : undefined
    }
  });
  if (error || !data.url) return fail(400, { message: 'Could not start Google sign-in. Please try again.' });
  redirect(303, data.url);
}

export const actions: Actions = {
  signIn: async ({ request, locals, url }) =>
    startGoogleOAuth(locals, url.origin, (await request.formData()).get('next'), 'sign_in'),
  requestAccess: async ({ request, locals, url }) =>
    startGoogleOAuth(locals, url.origin, (await request.formData()).get('next'), 'request_access')
};
