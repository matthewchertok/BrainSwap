import { error, fail, redirect } from '@sveltejs/kit';
import { requireSelectedMembership } from '$lib/server/membership';
import { profileSchema } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ locals, parent, url }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const [modelsResult, selectedResult, profileResult] = await Promise.all([
    locals.supabase
      .from('models')
      .select('id,display_name')
      .eq('organization_id', membership.organization_id)
      .eq('active', true),
    locals.supabase.from('member_models').select('model_id').eq('membership_id', membership.membership_id),
    locals.supabase
      .from('memberships')
      .select('display_name,capabilities,notification_preferences')
      .eq('id', membership.membership_id)
      .eq('organization_id', membership.organization_id)
      .maybeSingle()
  ]);
  if (modelsResult.error || selectedResult.error || profileResult.error || !profileResult.data)
    error(503, 'Profile data is temporarily unavailable.');
  return {
    models: modelsResult.data ?? [],
    selected: (selectedResult.data ?? []).map((item) => item.model_id),
    profile: profileResult.data,
    notice: url.searchParams.has('saved') ? 'Profile saved.' : null
  };
};
export const actions: Actions = {
  default: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const f = await request.formData();
    const parsed = profileSchema.safeParse({
      display_name: f.get('display_name'),
      capabilities: f.getAll('capabilities'),
      model_ids: f.getAll('model_ids'),
      notify: f.get('notify') === 'yes'
    });
    if (!parsed.success) return fail(400, { message: 'Review the profile values.' });
    const { error: updateError } = await locals.supabase.rpc('update_profile', {
      p_organization_id: membership.organization_id,
      p_display_name: parsed.data.display_name,
      p_capabilities: parsed.data.capabilities,
      p_model_ids: parsed.data.model_ids,
      p_preferences: { new_matching_jobs: parsed.data.notify }
    });
    if (updateError) return fail(400, { message: 'The profile could not be saved.' });
    redirect(303, '/app/profile?saved=1');
  }
};
