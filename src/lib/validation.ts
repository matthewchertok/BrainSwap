import { z } from 'zod';
const trimmed = (max: number) => z.string().trim().min(1).max(max);
export const jobSchema = z.object({
  title: trimmed(120),
  listing_summary: trimmed(1000),
  current_task: trimmed(100000),
  success_criteria: trimmed(25000),
  output_format: trimmed(10000),
  visibility: z.enum(['lab', 'claimed_only']),
  sensitivity: z.enum(['general', 'unpublished', 'collaborator', 'other']),
  sensitivity_notes: z.string().trim().max(10000).default(''),
  effort: z.enum(['quick', 'medium', 'heavy']),
  preferred_model_id: z.string().uuid(),
  required_tools: z.array(trimmed(80)).max(20),
  acknowledged: z.literal(true)
});
export const submissionSchema = z.object({
  model_used_text: trimmed(200),
  response_text: trimmed(500000),
  notes: z.string().trim().max(25000),
  tools_used: z.array(trimmed(80)).max(20)
});
export function safeReturnPath(value: string | null, fallback = '/app') {
  return value && value.startsWith('/') && !value.startsWith('//') && !value.includes('\\') ? value : fallback;
}
export function validExternalUrl(value: string, dev = false) {
  try {
    const u = new URL(value);
    return (
      u.protocol === 'https:' ||
      (dev && u.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(u.hostname))
    );
  } catch {
    return false;
  }
}
export const allowedFiles: Record<string, string[]> = {
  pdf: ['application/pdf'],
  txt: ['text/plain'],
  md: ['text/plain', 'text/markdown'],
  csv: ['text/csv', 'text/plain'],
  json: ['application/json'],
  png: ['image/png'],
  jpg: ['image/jpeg'],
  jpeg: ['image/jpeg'],
  webp: ['image/webp'],
  docx: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  pptx: ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
  xlsx: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
};
export function safeFilename(name: string) {
  const leaf = name.replace(/\\/g, '/').split('/').pop() || 'file';
  const ext = leaf.includes('.')
    ? '.' +
      leaf
        .split('.')
        .pop()!
        .toLowerCase()
        .replace(/[^a-z0-9]/g, '')
    : '';
  const stem =
    leaf
      .slice(0, leaf.length - ext.length)
      .normalize('NFKD')
      .replace(/[^a-zA-Z0-9_-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, Math.max(1, 240 - ext.length)) || 'file';
  return `${stem}${ext}`;
}
export function validFile(name: string, mime: string, size: number) {
  const ext = safeFilename(name).split('.').pop()?.toLowerCase() || '';
  return size > 0 && size <= 25 * 1024 * 1024 && !!allowedFiles[ext]?.includes(mime);
}
export function totalFileSize(files: { size_bytes: number }[]) {
  return files.reduce((n, f) => n + f.size_bytes, 0);
}
