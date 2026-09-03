import { fail, redirect } from '@sveltejs/kit';
import { safeReturnPath } from '$lib/validation';
import type { Actions, PageServerLoad } from './$types';

const authMessages: Record<string, string> = {
  missing_code: 'Google did not return a sign-in code. Please try again.',
  oauth_exchange: 'Google sign-in could not be completed. Please try again.',
  signout: 'You were signed out locally, but global session revocation could not be confirmed. Please try again later.',
  signout_failed:
    "Sign-out could not be confirmed. Clear this site's browser data, close the browser, and contact the lab operator."
};

export const load: PageServerLoad = ({ url }) => ({
  message: authMessages[url.searchParams.get('error') ?? ''] ?? null
});

export const actions: Actions = {
  default: async ({ locals, url }) => {
    const redirectTo = `${url.origin}/auth/callback?next=${encodeURIComponent(safeReturnPath(url.searchParams.get('next')))}`;
    const { data, error } = await locals.supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo, skipBrowserRedirect: true, scopes: 'openid email profile' }
    });
    if (error || !data.url) return fail(400, { message: 'Could not start Google sign-in. Please try again.' });
    redirect(303, data.url);
  }
};
