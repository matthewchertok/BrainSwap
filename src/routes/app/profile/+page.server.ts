import { fail } from '@sveltejs/kit';
import type { Actions } from './$types';
export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  const [{ data: models }, { data: selected }] = await Promise.all([
    locals.supabase
      .from('models')
      .select('id,display_name')
      .eq('organization_id', membership.organization_id)
      .eq('active', true),
    locals.supabase.from('member_models').select('model_id').eq('membership_id', membership.membership_id)
  ]);
  return { models: models ?? [], selected: (selected ?? []).map((x) => x.model_id) };
};
export const actions: Actions = {
  default: async ({ request, locals }) => {
    const f = await request.formData();
    const name = String(f.get('display_name') ?? '').trim();
    if (!name || name.length > 120) return fail(400, { message: 'Display name is required.' });
    const { error } = await locals.supabase.rpc('update_profile', {
      p_display_name: name,
      p_capabilities: f.getAll('capabilities'),
      p_model_ids: f.getAll('model_ids'),
      p_preferences: { new_matching_jobs: f.get('notify') === 'yes' }
    });
    return error ? fail(400, { message: error.message }) : { message: 'Profile saved.' };
  }
};
