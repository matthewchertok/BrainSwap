import { error, fail, redirect } from '@sveltejs/kit';
import { parseJobForm } from '$lib/server/job-form';
import { requireSelectedMembership } from '$lib/server/membership';
import { sendMetadataWebhook } from '$lib/server/notifications';
import { jobIdSchema, jobIntentSchema } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const { data: models, error: modelsError } = await locals.supabase
    .from('models')
    .select('id,display_name')
    .eq('organization_id', membership.organization_id)
    .eq('active', true)
    .order('sort_order');
  if (modelsError) error(503, 'Model configuration is temporarily unavailable.');
  return { models: models ?? [] };
};
export const actions: Actions = {
  default: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const f = await request.formData();
    const parsed = parseJobForm(f);
    if (!parsed.success)
      return fail(400, { message: 'Review the highlighted requirements.', issues: parsed.error.flatten().fieldErrors });
    const intent = jobIntentSchema.safeParse(f.get('intent'));
    if (!intent.success) return fail(400, { message: 'Choose whether to save or publish the draft.' });
    const { data, error: createError } = await locals.supabase.rpc('create_draft_job', {
      p_organization_id: membership.organization_id,
      p_input: parsed.input
    });
    if (createError) return fail(400, { message: 'The draft could not be created.' });
    const id = jobIdSchema.safeParse(data);
    if (!id.success) return fail(503, { message: 'The draft was created but its identifier was not returned.' });
    if (intent.data === 'publish') {
      const { error: publishError } = await locals.supabase.rpc('publish_job', { p_job_id: id.data });
      if (publishError) redirect(303, `/app/jobs/${id.data}?publish_error=1`);
      await sendMetadataWebhook({
        type: 'job_published',
        jobId: id.data,
        organizationId: membership.organization_id
      });
    }
    redirect(303, `/app/jobs/${id.data}?created=1`);
  }
};
