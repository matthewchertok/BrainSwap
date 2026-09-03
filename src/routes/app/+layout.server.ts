import { redirect } from '@sveltejs/kit';
import { getActiveMemberships, getSelectedMembership, setSelectedOrganization } from '$lib/server/membership';

export const load = async ({ locals, cookies, url }) => {
  if (!locals.userId) redirect(303, `/login?next=${encodeURIComponent(url.pathname)}`);
  const memberships = await getActiveMemberships(locals);
  if (!memberships.length) {
    const { error: signOutError } = await locals.supabase.auth.signOut();
    if (signOutError) await locals.supabase.auth.signOut({ scope: 'local' });
    redirect(303, '/unauthorized');
  }
  let membership = getSelectedMembership(cookies, memberships);
  if (!membership && memberships.length === 1) {
    membership = memberships[0]!;
    setSelectedOrganization(cookies, membership.organization_id, url.protocol === 'https:');
  }
  if (!membership && url.pathname !== '/app/select-organization') redirect(303, '/app/select-organization');
  return { membership, memberships };
};
