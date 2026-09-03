import { redirect } from '@sveltejs/kit';
export const load = async ({ locals, cookies, url }) => {
  if (!locals.userId) redirect(303, `/login?next=${encodeURIComponent(url.pathname)}`);
  const { data } = await locals.supabase.rpc('my_active_memberships');
  if (!data?.length) {
    await locals.supabase.auth.signOut();
    redirect(303, '/unauthorized');
  }
  let selected = cookies.get('brainswap_org');
  const active = data.find((m: { organization_id: string }) => m.organization_id === selected);
  if (!active) {
    if (data.length > 1) redirect(303, '/app/select-organization');
    const defaultOrganization = data[0]!.organization_id;
    selected = defaultOrganization;
    cookies.set('brainswap_org', defaultOrganization, {
      path: '/app',
      httpOnly: true,
      sameSite: 'lax',
      secure: url.protocol === 'https:',
      maxAge: 2592000
    });
  }
  return { membership: active ?? data[0], memberships: data };
};
