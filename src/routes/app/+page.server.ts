import { error } from '@sveltejs/kit';
import { dashboardTabSchema } from '$lib/validation';

export const load = async ({ locals, parent, url }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const tab = dashboardTabSchema.catch('open').parse(url.searchParams.get('tab') ?? 'open');
  const { data: jobs, error: jobsError } = await locals.supabase.rpc('dashboard_jobs', {
    p_organization_id: membership.organization_id,
    p_tab: tab
  });
  return { jobs: jobs ?? [], tab, loadFailed: !!jobsError };
};
