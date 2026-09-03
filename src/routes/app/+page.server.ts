export const load = async ({ locals, parent, url }) => {
  const { membership } = await parent();
  const tab = url.searchParams.get('tab') ?? 'open';
  const { data: jobs, error } = await locals.supabase.rpc('dashboard_jobs', {
    p_organization_id: membership.organization_id,
    p_tab: tab
  });
  return { jobs: jobs ?? [], tab, error: error?.message };
};
