import { fail, redirect } from '@sveltejs/kit';
import { safeReturnPath } from '$lib/validation';
import type { Actions } from './$types';
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
