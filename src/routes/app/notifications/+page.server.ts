export const load = async ({ locals, parent }) => {
  const { membership } = await parent();
  const { data } = await locals.supabase
    .from('notifications')
    .select('id,type,message,read_at,created_at,job_id')
    .eq('recipient_membership_id', membership.membership_id)
    .order('created_at', { ascending: false })
    .limit(100);
  return { notifications: data ?? [] };
};
