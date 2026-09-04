import { error, fail, redirect } from '@sveltejs/kit';
import { parseJobForm } from '$lib/server/job-form';
import { requireSelectedMembership } from '$lib/server/membership';
import { sendMetadataWebhook } from '$lib/server/notifications';
import { uploadReservedFile } from '$lib/storage';
import { jobIdSchema, jobIntentSchema, validJobAttachmentZip } from '$lib/validation';
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
    const attachmentValue = f.get('job_attachment');
    const attachment =
      attachmentValue && typeof attachmentValue !== 'string' && attachmentValue.size ? attachmentValue : null;
    if (attachment && !validJobAttachmentZip(attachment.name, attachment.type, attachment.size))
      return fail(400, { message: 'Choose one ZIP file no larger than 25 MiB.' });
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
    if (attachment) {
      const attached = await uploadInitialAttachment(locals.supabase, id.data, attachment);
      if (!attached) redirect(303, `/app/jobs/${id.data}?attachment_error=1`);
    }
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

async function uploadInitialAttachment(client: App.Locals['supabase'], jobId: string, attachment: File) {
  const { data: rows, error: reserveError } = await client.rpc('reserve_job_file', {
    p_job_id: jobId,
    p_filename: attachment.name,
    p_mime_type: attachment.type,
    p_size_bytes: attachment.size,
    p_description: null
  });
  const reservation = Array.isArray(rows) ? rows[0] : rows;
  if (reserveError || !reservation?.id || !reservation.storage_path) return false;

  try {
    await uploadReservedFile(client, reservation.storage_path, attachment, 'job');
    const { error: finalizeError } = await client.rpc('finalize_job_file', { p_file_id: reservation.id });
    if (finalizeError) throw new Error('finalization failed');
    return true;
  } catch {
    const { data: cleanupRows } = await client.rpc('file_cleanup_info', {
      p_file_id: reservation.id,
      p_kind: 'job'
    });
    const cleanup = Array.isArray(cleanupRows) ? cleanupRows[0] : cleanupRows;
    if (cleanup?.storage_path) {
      await client.storage.from('job-files').remove([cleanup.storage_path]);
      await client.rpc('delete_file_record', { p_file_id: reservation.id, p_kind: 'job' });
    }
    return false;
  }
}
