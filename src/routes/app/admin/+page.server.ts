import { error, fail } from '@sveltejs/kit';
import type { Actions } from './$types';
export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  if (membership.role !== 'admin') error(404);
  const [{ data: members }, { data: models }, { data: audit }] = await Promise.all([
    locals.supabase.rpc('admin_memberships', { p_organization_id: membership.organization_id }),
    locals.supabase
      .from('models')
      .select('id,display_name,provider,active')
      .eq('organization_id', membership.organization_id),
    locals.supabase
      .from('audit_events')
      .select('event_type,created_at,metadata')
      .eq('organization_id', membership.organization_id)
      .order('created_at', { ascending: false })
      .limit(50)
  ]);
  return { members: members ?? [], models: models ?? [], audit: audit ?? [] };
};
export const actions: Actions = {
  invite: async ({ request, locals }) => {
    const { data: memberships } = await locals.supabase.rpc('my_active_memberships');
    const membership = memberships?.find((m: { role: string }) => m.role === 'admin');
    if (!membership) return fail(403, { message: 'Administrator access required.' });
    const f = await request.formData();
    const email = String(f.get('email') ?? '')
      .trim()
      .toLowerCase();
    const { error } = await locals.supabase.rpc('admin_upsert_membership', {
      p_organization_id: membership.organization_id,
      p_email: email,
      p_role: f.get('role')
    });
    return error ? fail(400, { message: error.message }) : { message: 'Invitation saved.' };
  }
};
