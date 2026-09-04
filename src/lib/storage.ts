import type { SupabaseClient } from '@supabase/supabase-js';
import { safeFilename, validFile, validJobAttachmentZip } from './validation';
export async function uploadReservedFile(
  client: SupabaseClient,
  path: string,
  file: File,
  kind: 'job' | 'submission' = 'submission'
) {
  const valid =
    kind === 'job'
      ? validJobAttachmentZip(file.name, file.type, file.size)
      : validFile(file.name, file.type, file.size);
  if (!valid) throw new Error('Unsupported filename, file type, or size.');
  const body = await file.arrayBuffer();
  const { error } = await client.storage
    .from('job-files')
    .upload(path, body, { contentType: file.type, upsert: false });
  if (error) throw new Error('The reserved file upload failed.');
}
export async function downloadPrivateFile(client: SupabaseClient, path: string, filename: string) {
  const { data, error } = await client.storage.from('job-files').download(path);
  if (error) throw new Error('The file download failed.');
  const url = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = url;
  a.download = safeFilename(filename);
  a.rel = 'noopener';
  document.body.append(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
}

export async function downloadProfilePhotoUrl(client: SupabaseClient, path: string) {
  const { data, error } = await client.storage.from('profile-photos').download(path);
  if (error) throw new Error('The profile photo is not available.');
  return URL.createObjectURL(data);
}
