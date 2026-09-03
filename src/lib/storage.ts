import type { SupabaseClient } from '@supabase/supabase-js';
import { safeFilename, validFile } from './validation';
export async function uploadReservedFile(client: SupabaseClient, path: string, file: File) {
  if (!validFile(safeFilename(file.name), file.type, file.size)) throw new Error('Unsupported file type or size.');
  const { error } = await client.storage
    .from('job-files')
    .upload(path, file, { contentType: file.type, upsert: false });
  if (error) throw error;
}
export async function downloadPrivateFile(client: SupabaseClient, path: string, filename: string) {
  const { data, error } = await client.storage.from('job-files').download(path);
  if (error) throw error;
  const url = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = url;
  a.download = safeFilename(filename);
  a.rel = 'noopener';
  a.click();
  URL.revokeObjectURL(url);
}
