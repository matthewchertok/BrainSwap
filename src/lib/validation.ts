import { z } from 'zod';
const trimmed = (max: number) => z.string().trim().min(1).max(max);
const preservedRequired = (max: number) =>
  z
    .string()
    .max(max)
    .refine((value) => value.trim().length > 0, 'This field cannot be blank.');
const preservedOptional = (max: number) =>
  z
    .string()
    .max(max)
    .transform((value) => (value.trim().length ? value : ''));
export const JOB_TOOLS = [
  'Web access',
  'Deep research',
  'Code execution',
  'Image understanding',
  'PDF understanding',
  'File generation',
  'Other'
] as const;
export const PROFILE_CAPABILITIES = JOB_TOOLS.filter((tool) => tool !== 'Other');
const uuid = z.string().uuid();
const unique = <T>(values: T[]) => new Set(values).size === values.length;

export const jobSchema = z
  .object({
    title: trimmed(120),
    listing_summary: trimmed(1000),
    current_task: preservedRequired(100000),
    success_criteria: preservedRequired(25000),
    output_format: preservedRequired(10000),
    visibility: z.enum(['lab', 'claimed_only']),
    sensitivity: z.enum(['general', 'unpublished', 'collaborator', 'other']),
    sensitivity_notes: z.string().trim().max(10000).default(''),
    effort: z.enum(['quick', 'medium', 'heavy']),
    preferred_model_id: uuid,
    acceptable_model_ids: z.array(uuid).max(10).refine(unique, 'Choose each acceptable model once.'),
    deadline: z.iso
      .datetime({ offset: true })
      .nullable()
      .refine((value) => value === null || new Date(value).getTime() > Date.now(), 'Deadline must be in the future.'),
    prior_context: preservedOptional(250000).default(''),
    external_urls: z.array(z.string().trim().max(2048)).max(10).refine(unique, 'Enter each link once.'),
    required_tools: z.array(z.enum(JOB_TOOLS)).max(JOB_TOOLS.length).refine(unique, 'Choose each tool once.'),
    acknowledged: z.literal(true)
  })
  .superRefine((data, context) => {
    if (data.acceptable_model_ids.includes(data.preferred_model_id))
      context.addIssue({
        code: 'custom',
        path: ['acceptable_model_ids'],
        message: 'The preferred model is already included.'
      });
    data.external_urls.forEach((url, index) => {
      if (!validExternalUrl(url))
        context.addIssue({
          code: 'custom',
          path: ['external_urls', index],
          message: 'Links must use HTTPS and must not contain credentials.'
        });
    });
  });
export const submissionSchema = z.object({
  model_used_text: trimmed(200),
  response_text: preservedRequired(500000),
  notes: z.string().trim().max(25000).default(''),
  tools_used: z.array(z.enum(JOB_TOOLS)).max(JOB_TOOLS.length).refine(unique, 'Choose each tool once.')
});

export const jobIdSchema = uuid;
export const jobIntentSchema = z.enum(['draft', 'publish']);
export const dashboardTabSchema = z.enum(['open', 'drafts', 'requests', 'claimed', 'review', 'completed']);
export const revisionSchema = z.object({ instructions: trimmed(25000) });
export const adminInviteSchema = z.object({
  email: z.string().trim().toLowerCase().max(254).email(),
  role: z.enum(['member', 'admin'])
});
export const adminMembershipSchema = z.object({
  membership_id: uuid,
  role: z.enum(['member', 'admin']),
  active: z.boolean()
});
export const profileSchema = z.object({
  display_name: trimmed(120),
  capabilities: z
    .array(z.enum(PROFILE_CAPABILITIES as [string, ...string[]]))
    .max(PROFILE_CAPABILITIES.length)
    .refine(unique, 'Choose each capability once.'),
  model_ids: z.array(uuid).max(50).refine(unique, 'Choose each model once.'),
  notify: z.boolean()
});

export function safeReturnPath(value: string | null, fallback = '/app') {
  if (!value || !value.startsWith('/') || value.includes('\\') || hasUnsafeAscii(value)) return fallback;
  try {
    const sentinel = new URL('https://internal.brainswap.invalid');
    const parsed = new URL(value, sentinel);
    if (parsed.origin !== sentinel.origin || (parsed.pathname !== '/app' && !parsed.pathname.startsWith('/app/')))
      return fallback;
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return fallback;
  }
}
export function validExternalUrl(value: string) {
  if (value !== value.trim() || hasUnsafeAscii(value) || !value.startsWith('https://')) return false;
  try {
    const u = new URL(value);
    if (u.username || u.password) return false;
    const authority = value.slice('https://'.length).split(/[/?#]/, 1)[0];
    if (!authority || authority.includes('@') || authority.startsWith('[')) return false;

    const portMatch = authority.match(/:([0-9]+)$/);
    const host = portMatch ? authority.slice(0, -portMatch[0].length) : authority;
    if ((!portMatch && authority.includes(':')) || host.length > 253) return false;
    if (
      !/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/.test(host)
    )
      return false;
    if (/^[0-9.]+$/.test(host)) {
      const octets = host.split('.');
      if (octets.length !== 4 || octets.some((octet) => !/^\d{1,3}$/.test(octet) || Number(octet) > 255)) return false;
    }
    if (portMatch && (Number(portMatch[1]) < 1 || Number(portMatch[1]) > 65535)) return false;
    return u.protocol === 'https:';
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
  if (
    name.length < 1 ||
    name.length > 255 ||
    name !== name.trim() ||
    name.startsWith('.') ||
    name.includes('/') ||
    name.includes('\\') ||
    hasUnsafeAscii(name)
  )
    return false;
  const ext = name.match(/\.([A-Za-z0-9]+)$/)?.[1]?.toLowerCase() ?? '';
  return size > 0 && size <= 25 * 1024 * 1024 && !!allowedFiles[ext]?.includes(mime);
}
export function totalFileSize(files: { size_bytes: number }[]) {
  return files.reduce((n, f) => n + f.size_bytes, 0);
}

function hasUnsafeAscii(value: string) {
  return Array.from(value).some((character) => {
    const code = character.charCodeAt(0);
    return code <= 32 || code === 127;
  });
}
