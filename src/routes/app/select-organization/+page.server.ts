import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
export const actions: Actions = {
  default: async ({ request, locals, cookies, url }) => {
    const id = String((await request.formData()).get('organization_id'));
    const { data } = await locals.supabase.rpc('my_active_memberships');
    if (!data?.some((m: { organization_id: string }) => m.organization_id === id))
      return fail(403, { message: 'That organization is not available.' });
    cookies.set('brainswap_org', id, {
      path: '/app',
      httpOnly: true,
      sameSite: 'lax',
      secure: url.protocol === 'https:',
      maxAge: 2592000
    });
    redirect(303, '/app');
  }
};
