import { error, fail } from '@sveltejs/kit';
import type { Actions } from './$types';
export const load = async ({ locals, params }) => {
  const { data, error: e } = await locals.supabase.rpc('job_workspace', { p_job_id: params.id });
  if (e || !data) error(404, 'Job not found or not available');
  return { workspace: data };
};
export const actions: Actions = {
  claim: async ({ locals, params }) => rpc(locals, 'claim_job', params.id),
  release: async ({ locals, params }) => rpc(locals, 'release_job', params.id),
  extend: async ({ locals, params }) => rpc(locals, 'extend_claim', params.id),
  accept: async ({ locals, params }) => rpc(locals, 'accept_job', params.id),
  cancel: async ({ locals, params }) => rpc(locals, 'cancel_job', params.id),
  reopen: async ({ locals, params }) => rpc(locals, 'reopen_job', params.id),
  revise: async ({ locals, params, request }) => {
    const instructions = String((await request.formData()).get('instructions') ?? '').trim();
    if (!instructions || instructions.length > 25000)
      return fail(400, { message: 'Revision instructions are required.' });
    return rpc(locals, 'request_revision', params.id, { p_instructions: instructions });
  },
  submit: async ({ locals, params, request }) => {
    const f = await request.formData();
    return rpc(locals, 'submit_result', params.id, {
      p_model_used_text: String(f.get('model_used_text')),
      p_response_text: String(f.get('response_text')),
      p_notes: String(f.get('notes') ?? '')
    });
  }
};
async function rpc(locals: App.Locals, name: string, id: string, extra = {}) {
  const { error: e } = await locals.supabase.rpc(name, { p_job_id: id, ...extra });
  return e ? fail(400, { message: e.message }) : { success: true };
}
