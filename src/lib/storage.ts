import type { SupabaseClient } from '@supabase/supabase-js';
import { safeFilename, validFile, validProfilePhoto } from './validation';
export async function uploadReservedFile(client: SupabaseClient, path: string, file: File) {
  if (!validFile(file.name, file.type, file.size)) throw new Error('Unsupported filename, file type, or size.');
  const { error } = await client.storage
    .from('job-files')
    .upload(path, file, { contentType: file.type, upsert: false });
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

export async function uploadReservedProfilePhoto(client: SupabaseClient, path: string, file: File) {
  if (!validProfilePhoto(file.name, file.type, file.size))
    throw new Error('Choose a JPEG, PNG, or WebP image no larger than 5 MiB.');
  const { error } = await client.storage
    .from('profile-photos')
    .upload(path, file, { contentType: file.type, upsert: false });
  if (error) throw new Error('The reserved profile photo upload failed.');
}

export async function downloadProfilePhotoUrl(client: SupabaseClient, path: string) {
  const { data, error } = await client.storage.from('profile-photos').download(path);
  if (error) throw new Error('The profile photo is not available.');
  return URL.createObjectURL(data);
}
