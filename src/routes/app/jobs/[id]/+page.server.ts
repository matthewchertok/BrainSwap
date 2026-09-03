import { error, fail, redirect, type Cookies } from '@sveltejs/kit';
import { parseJobForm } from '$lib/server/job-form';
import { requireSelectedMembership, type ActiveMembership } from '$lib/server/membership';
import { sendMetadataWebhook } from '$lib/server/notifications';
import { jobIdSchema, revisionSchema, submissionSchema } from '$lib/validation';
import type { Actions } from './$types';

export const load = async ({ locals, params, url, parent }) => {
  const id = jobIdSchema.safeParse(params.id);
  if (!id.success) error(404, 'Job not found or not available');
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const { data: job, error: jobError } = await locals.supabase
    .from('jobs')
    .select('id')
    .eq('id', id.data)
    .eq('organization_id', membership.organization_id)
    .maybeSingle();
  if (jobError || !job) error(404, 'Job not found or not available');
  const { data, error: workspaceError } = await locals.supabase.rpc('job_workspace', { p_job_id: id.data });
  if (workspaceError || !data) error(404, 'Job not found or not available');
  const { data: availableModels, error: modelsError } = await locals.supabase
    .from('models')
    .select('id,display_name,provider,sort_order')
    .eq('organization_id', membership.organization_id)
    .eq('active', true)
    .order('sort_order');
  if (modelsError) error(503, 'Model configuration is temporarily unavailable.');
  return {
    workspace: data,
    availableModels: availableModels ?? [],
    notice: notice(url.searchParams),
    publishError: url.searchParams.has('publish_error')
  };
};

export const actions: Actions = {
  claim: async (event) => workflowMutation(event, 'claim_job', 'job_claimed'),
  release: async (event) => workflowMutation(event, 'release_job', 'job_released'),
  extend: async (event) => workflowMutation(event, 'extend_claim', 'claim_extended'),
  accept: async (event) => workflowMutation(event, 'accept_job', 'job_accepted'),
  cancel: async (event) => workflowMutation(event, 'cancel_job', 'job_cancelled'),
  reopen: async (event) => workflowMutation(event, 'reopen_job', 'job_reopened'),
  publish: async (event) => workflowMutation(event, 'publish_job', 'job_published'),
  update: async ({ locals, params, request, cookies, url }) => {
    const { id } = await actionContext(locals, cookies, url, params.id);
    const form = await request.formData();
    const parsed = parseJobForm(form);
    if (!parsed.success)
      return fail(400, {
        message: 'Review the draft requirements.',
        issues: parsed.error.flatten().fieldErrors
      });
    const { error: updateError } = await locals.supabase.rpc('update_draft_job', {
      p_job_id: id,
      p_input: parsed.input
    });
    if (updateError) return fail(400, { message: 'The draft could not be updated.' });
    redirect(303, `/app/jobs/${id}?saved=1`);
  },
  revise: async ({ locals, params, request, cookies, url }) => {
    const { id, membership } = await actionContext(locals, cookies, url, params.id);
    const form = await request.formData();
    const parsed = revisionSchema.safeParse({ instructions: form.get('instructions') });
    if (!parsed.success) return fail(400, { message: 'Revision instructions are required and must be concise.' });
    const { error: revisionError } = await locals.supabase.rpc('request_revision', {
      p_job_id: id,
      p_instructions: parsed.data.instructions
    });
    if (revisionError) return fail(400, { message: 'The revision request could not be saved.' });
    await notify('revision_requested', id, membership);
    redirect(303, `/app/jobs/${id}?revised=1`);
  },
  submit: async ({ locals, params, request, cookies, url }) => {
    const { id, membership } = await actionContext(locals, cookies, url, params.id);
    const form = await request.formData();
    const parsed = submissionSchema.safeParse({
      model_used_text: form.get('model_used_text'),
      response_text: form.get('response_text'),
      notes: form.get('notes') ?? '',
      tools_used: form.getAll('tools_used')
    });
    if (!parsed.success) return fail(400, { message: 'Review the result fields and limits.' });
    const { error: submissionError } = await locals.supabase.rpc('submit_result', {
      p_job_id: id,
      p_model_used_text: parsed.data.model_used_text,
      p_response_text: parsed.data.response_text,
      p_notes: parsed.data.notes,
      p_tools_used: parsed.data.tools_used
    });
    if (submissionError) return fail(400, { message: 'The result could not be submitted.' });
    await notify('result_submitted', id, membership);
    redirect(303, `/app/jobs/${id}?submitted=1`);
  },
  follow_up: async ({ locals, params, cookies, url }) => {
    const { id, membership } = await actionContext(locals, cookies, url, params.id);
    const { data, error: followUpError } = await locals.supabase.rpc('create_follow_up_draft', {
      p_job_id: id
    });
    const child = jobIdSchema.safeParse(data);
    if (followUpError || !child.success) return fail(400, { message: 'The follow-up draft could not be created.' });
    await notify('follow_up_created', id, membership);
    redirect(303, `/app/jobs/${child.data}?created=follow-up`);
  }
};

async function workflowMutation(
  event: { locals: App.Locals; cookies: Cookies; url: URL; params: { id: string } },
  rpcName: string,
  eventType: string
) {
  const { id, membership } = await actionContext(event.locals, event.cookies, event.url, event.params.id);
  const { error: mutationError } = await event.locals.supabase.rpc(rpcName, { p_job_id: id });
  if (mutationError) return fail(400, { message: 'That workflow change is not currently allowed.' });
  await notify(eventType, id, membership);
  redirect(303, `/app/jobs/${id}?changed=${encodeURIComponent(eventType)}`);
}

async function actionContext(locals: App.Locals, cookies: Cookies, url: URL, rawId: string) {
  const parsed = jobIdSchema.safeParse(rawId);
  if (!parsed.success) error(404, 'Job not found or not available');
  const membership = await requireSelectedMembership(locals, cookies, url);
  const { data, error: lookupError } = await locals.supabase
    .from('jobs')
    .select('id')
    .eq('id', parsed.data)
    .eq('organization_id', membership.organization_id)
    .maybeSingle();
  if (lookupError || !data) error(404, 'Job not found or not available');
  return { id: parsed.data, membership };
}

async function notify(type: string, jobId: string, membership: ActiveMembership) {
  await sendMetadataWebhook({ type, jobId, organizationId: membership.organization_id });
}

function notice(params: URLSearchParams) {
  if (params.has('created')) return 'Draft created.';
  if (params.has('saved')) return 'Draft saved.';
  if (params.has('submitted')) return 'Result submitted.';
  if (params.has('revised')) return 'Revision requested.';
  if (params.has('changed')) return 'Job updated.';
  return null;
}
