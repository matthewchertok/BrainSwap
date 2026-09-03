import { error, fail, redirect } from '@sveltejs/kit';
import { requireSelectedMembership } from '$lib/server/membership';
import { profileSchema, validProfilePhoto } from '$lib/validation';
import type { Actions } from './$types';
export const load = async ({ locals, parent, url }) => {
  const { membership } = await parent();
  if (!membership) error(409, 'Select an organization first.');
  const [modelsResult, selectedResult, profileResult, photoResult] = await Promise.all([
    locals.supabase
      .from('models')
      .select('id,display_name')
      .eq('organization_id', membership.organization_id)
      .eq('active', true)
      .order('sort_order'),
    locals.supabase.from('member_models').select('model_id').eq('membership_id', membership.membership_id),
    locals.supabase
      .from('memberships')
      .select('display_name,bio,notification_preferences')
      .eq('id', membership.membership_id)
      .eq('organization_id', membership.organization_id)
      .maybeSingle(),
    locals.supabase
      .from('profile_photos')
      .select('id,mime_type,size_bytes,upload_status,cleanup_started_at')
      .eq('membership_id', membership.membership_id)
      .eq('organization_id', membership.organization_id)
      .maybeSingle()
  ]);
  if (modelsResult.error || selectedResult.error || profileResult.error || photoResult.error || !profileResult.data)
    error(503, 'Profile data is temporarily unavailable.');
  return {
    models: modelsResult.data ?? [],
    selected: (selectedResult.data ?? []).map((item) => item.model_id),
    profile: profileResult.data,
    photo: photoResult.data,
    membershipId: membership.membership_id,
    organizationId: membership.organization_id,
    organizationName: membership.organization_name,
    notice:
      url.searchParams.get('photo') === 'uploaded'
        ? 'Profile photo updated.'
        : url.searchParams.has('saved')
          ? 'Profile saved.'
          : null
  };
};
export const actions: Actions = {
  upload_photo: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const form = await request.formData();
    const photo = form.get('photo');
    if (!(photo instanceof File) || !validProfilePhoto(photo.name, photo.type, photo.size))
      return fail(400, { message: 'Choose a JPEG, PNG, or WebP image no larger than 5 MiB.' });

    const { data: rows, error: reserveError } = await locals.supabase.rpc('reserve_profile_photo', {
      p_organization_id: membership.organization_id,
      p_filename: photo.name,
      p_mime_type: photo.type,
      p_size_bytes: photo.size
    });
    const reservation = Array.isArray(rows) ? rows[0] : rows;
    if (reserveError || !reservation?.id || !reservation.storage_path)
      return fail(400, {
        message: 'The profile photo could not be reserved. Remove any existing photo and try again.'
      });

    const cleanupReservation = async () => {
      const { data: cleanupRows, error: cleanupError } = await locals.supabase.rpc('profile_photo_cleanup_info', {
        p_photo_id: reservation.id
      });
      const cleanup = Array.isArray(cleanupRows) ? cleanupRows[0] : cleanupRows;
      if (cleanupError || !cleanup?.storage_path) return;
      const { error: removeError } = await locals.supabase.storage
        .from('profile-photos')
        .remove([cleanup.storage_path]);
      if (!removeError) await locals.supabase.rpc('delete_profile_photo_record', { p_photo_id: reservation.id });
    };

    const { error: uploadError } = await locals.supabase.storage
      .from('profile-photos')
      .upload(reservation.storage_path, photo, { contentType: photo.type, upsert: false });
    if (uploadError) {
      await cleanupReservation();
      return fail(400, { message: 'The profile photo could not be uploaded. Please try again.' });
    }

    const { error: finalizeError } = await locals.supabase.rpc('finalize_profile_photo', {
      p_photo_id: reservation.id
    });
    if (finalizeError) {
      await cleanupReservation();
      return fail(400, { message: 'The profile photo could not be finalized. Please try again.' });
    }
    redirect(303, '/app/profile?photo=uploaded');
  },
  save: async ({ request, locals, cookies, url }) => {
    const membership = await requireSelectedMembership(locals, cookies, url);
    const f = await request.formData();
    const parsed = profileSchema.safeParse({
      display_name: f.get('display_name'),
      bio: f.get('bio') ?? '',
      model_ids: f.getAll('model_ids'),
      notify: f.get('notify') === 'yes'
    });
    if (!parsed.success) return fail(400, { message: 'Review the profile values.' });
    const { error: updateError } = await locals.supabase.rpc('update_profile', {
      p_organization_id: membership.organization_id,
      p_display_name: parsed.data.display_name,
      p_bio: parsed.data.bio,
      p_model_ids: parsed.data.model_ids,
      p_preferences: { new_matching_jobs: parsed.data.notify }
    });
    if (updateError) return fail(400, { message: 'The profile could not be saved.' });
    redirect(303, '/app/profile?saved=1');
  }
};
