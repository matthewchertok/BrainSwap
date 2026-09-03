import { redirect } from '@sveltejs/kit';
export const POST = async ({ locals }) => {
  const { error } = await locals.supabase.auth.signOut();
  if (error) {
    const { error: localError } = await locals.supabase.auth.signOut({ scope: 'local' });
    redirect(303, localError ? '/login?error=signout_failed' : '/login?error=signout');
  }
  redirect(303, '/login');
};
