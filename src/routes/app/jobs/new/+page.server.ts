import { fail, redirect } from '@sveltejs/kit';
import { jobSchema } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  const { data: models } = await locals.supabase
    .from('models')
    .select('id,display_name')
    .eq('organization_id', membership.organization_id)
    .eq('active', true)
    .order('sort_order');
  return { models: models ?? [] };
};
export const actions: Actions = {
  default: async ({ request, locals }) => {
    const { data: memberships } = await locals.supabase.rpc('my_active_memberships');
    const membership = memberships?.[0];
    if (!membership) return fail(403, { message: 'Active membership required.' });
    const f = await request.formData();
    const parsed = jobSchema.safeParse({
      title: f.get('title'),
      listing_summary: f.get('listing_summary'),
      current_task: f.get('current_task'),
      success_criteria: f.get('success_criteria'),
      output_format: f.get('output_format'),
      visibility: f.get('visibility'),
      sensitivity: f.get('sensitivity'),
      sensitivity_notes: f.get('sensitivity_notes') ?? '',
      effort: f.get('effort'),
      preferred_model_id: f.get('preferred_model_id'),
      required_tools: f.getAll('required_tools'),
      acknowledged: f.get('acknowledged') === 'yes'
    });
    if (!parsed.success)
      return fail(400, { message: 'Review the highlighted requirements.', issues: parsed.error.flatten().fieldErrors });
    const { data, error } = await locals.supabase.rpc('create_draft_job', {
      p_organization_id: membership.organization_id,
      p_input: parsed.data
    });
    if (error) return fail(400, { message: error.message });
    const id = typeof data === 'string' ? data : data?.id;
    if (f.get('intent') === 'publish') {
      const { error: e } = await locals.supabase.rpc('publish_job', { p_job_id: id });
      if (e) return fail(400, { message: e.message });
    }
    redirect(303, `/app/jobs/${id}`);
  }
};
