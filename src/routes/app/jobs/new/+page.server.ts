import { error, fail, redirect } from '@sveltejs/kit';
import { parseJobForm } from '$lib/server/job-form';
import { requireSelectedMembership } from '$lib/server/membership';
import { sendMetadataWebhook } from '$lib/server/notifications';
import { jobIdSchema, jobIntentSchema } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ parent }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  return {};
};
export const actions: Actions = {
  default: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const f = await request.formData();
    const intent = jobIntentSchema.safeParse(f.get('intent'));
    if (!intent.success) return fail(400, { message: 'Choose whether to save or publish the draft.' });
    const parsed = parseJobForm(f, intent.data);
    if (!parsed.success)
      return fail(400, {
        message:
          intent.data === 'draft'
            ? 'The draft contains an invalid value. Review the fields and try again.'
            : 'Complete the required fields before publishing.',
        issues: parsed.error.flatten().fieldErrors
      });
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
      redirect(303, `/app/jobs/${id.data}?published=1`);
    }
    redirect(303, `/app/jobs/${id.data}?created=1`);
  }
};
