import { error, fail, redirect } from '@sveltejs/kit';
import { requireSelectedMembership } from '$lib/server/membership';
import { jobIdSchema } from '$lib/validation';
import type { Actions } from './$types';

export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const { data, error: notificationError } = await locals.supabase
    .from('notifications')
    .select('id,type,message,read_at,created_at,job_id')
    .eq('recipient_membership_id', membership.membership_id)
    .order('created_at', { ascending: false })
    .limit(100);
  if (notificationError) error(503, 'Notifications are temporarily unavailable.');
  return { notifications: data ?? [] };
};

export const actions: Actions = {
  read: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const form = await request.formData();
    const id = jobIdSchema.safeParse(form.get('notification_id'));
    if (!id.success) return fail(400, { message: 'Invalid notification.' });
    const { data: notification, error: lookupError } = await locals.supabase
      .from('notifications')
      .select('id')
      .eq('id', id.data)
      .eq('recipient_membership_id', membership.membership_id)
      .maybeSingle();
    if (lookupError || !notification) return fail(404, { message: 'Notification not found.' });
    const { error: readError } = await locals.supabase.rpc('mark_notification_read', {
      p_notification_id: id.data
    });
    if (readError) return fail(400, { message: 'The notification could not be marked read.' });
    redirect(303, '/app/notifications');
  }
};
