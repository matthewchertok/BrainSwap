import { error, fail, redirect } from '@sveltejs/kit';
import { requireSelectedMembership } from '$lib/server/membership';
import { adminDeleteInvitationSchema, adminInviteSchema, adminMembershipSchema } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ locals, parent, url }) => {
  const { membership } = await parent();
  if (membership?.role !== 'admin') error(404);
  const { data: members, error: membersError } = await locals.supabase.rpc('admin_memberships', {
    p_organization_id: membership.organization_id
  });
  if (membersError) error(503, 'Administration data is temporarily unavailable.');
  return {
    members: members ?? [],
    notice:
      url.searchParams.get('saved') === 'invitation-deleted'
        ? 'Invitation removed.'
        : url.searchParams.has('saved')
          ? 'Membership saved.'
          : null
  };
};
export const actions: Actions = {
  invite: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    if (membership.role !== 'admin') return fail(403, { message: 'Administrator access required.' });
    const f = await request.formData();
    const parsed = adminInviteSchema.safeParse({ email: f.get('email'), role: f.get('role') });
    if (!parsed.success) return fail(400, { message: 'Enter a valid exact email and role.' });
    const { error: invitationError } = await locals.supabase.rpc('admin_upsert_membership', {
      p_organization_id: membership.organization_id,
      p_email: parsed.data.email,
      p_role: parsed.data.role
    });
    if (invitationError) return fail(400, { message: 'The invitation could not be saved.' });
    redirect(303, '/app/admin?saved=invite');
  },
  membership: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    if (membership.role !== 'admin') return fail(403, { message: 'Administrator access required.' });
    const f = await request.formData();
    const parsed = adminMembershipSchema.safeParse({
      membership_id: f.get('membership_id'),
      role: f.get('role'),
      active: f.get('active') === 'yes'
    });
    if (!parsed.success) return fail(400, { message: 'Review the membership values.' });
    const { error: updateError } = await locals.supabase.rpc('admin_update_membership', {
      p_organization_id: membership.organization_id,
      p_membership_id: parsed.data.membership_id,
      p_role: parsed.data.role,
      p_active: parsed.data.active
    });
    if (updateError) return fail(400, { message: 'The membership could not be updated.' });
    redirect(303, '/app/admin?saved=membership');
  },
  delete_invitation: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    if (membership.role !== 'admin') return fail(403, { message: 'Administrator access required.' });
    const form = await request.formData();
    const parsed = adminDeleteInvitationSchema.safeParse({ membership_id: form.get('membership_id') });
    if (!parsed.success) return fail(400, { message: 'The invitation could not be identified.' });
    const { error: deleteError } = await locals.supabase.rpc('admin_delete_unclaimed_invitation', {
      p_organization_id: membership.organization_id,
      p_membership_id: parsed.data.membership_id
    });
    if (deleteError) return fail(400, { message: 'Only an unclaimed invitation can be removed.' });
    redirect(303, '/app/admin?saved=invitation-deleted');
  }
};
