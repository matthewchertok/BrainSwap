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
export const PROFILE_MODELS = [
  'GPT-6 Astra',
  'GPT-5.6 Sol',
  'GPT-5.6 Terra',
  'GPT-5.6 Luna',
  'Claude Fable 5.1',
  'Claude Opus 5',
  'Gemini Pro',
  'SuperGrok'
] as const;
export const REASONING_EFFORTS = ['low', 'medium', 'high', 'extra_high', 'max', 'ultra', 'other'] as const;
const uuid = z.string().uuid();
const unique = <T>(values: T[]) => new Set(values).size === values.length;

const absoluteDeadline = z.iso.datetime({ offset: true }).nullable();
const jobShape = z.object({
  title: z.string().trim().max(120),
  task_summary: z.string().trim().max(1000),
  prompt: preservedOptional(100000).default(''),
  helper_instructions: preservedOptional(25000).default(''),
  chat_url: z.string().trim().max(2048).default(''),
  preferred_model_text: z.string().trim().max(200),
  acceptable_models_text: z.string().trim().max(1000),
  deadline: absoluteDeadline
});

export const jobDraftSchema = jobShape.superRefine((data, context) => {
  if (data.chat_url && !validExternalUrl(data.chat_url))
    context.addIssue({
      code: 'custom',
      path: ['chat_url'],
      message: 'The chat link must use HTTPS and must not contain credentials.'
    });
  if (data.deadline && new Date(data.deadline).getTime() <= Date.now())
    context.addIssue({ code: 'custom', path: ['deadline'], message: 'Deadline must be in the future.' });
});

export const jobPublishSchema = jobShape.superRefine((data, context) => {
  for (const [field, value] of [
    ['title', data.title],
    ['task_summary', data.task_summary],
    ['prompt', data.prompt],
    ['chat_url', data.chat_url],
    ['preferred_model_text', data.preferred_model_text]
  ] as const) {
    if (!value.trim())
      context.addIssue({ code: 'custom', path: [field], message: 'This field is required to publish.' });
  }
  if (data.chat_url && !validExternalUrl(data.chat_url))
    context.addIssue({
      code: 'custom',
      path: ['chat_url'],
      message: 'The chat link must use HTTPS and must not contain credentials.'
    });
  if (data.deadline && new Date(data.deadline).getTime() <= Date.now())
    context.addIssue({ code: 'custom', path: ['deadline'], message: 'Deadline must be in the future.' });
});

// Retain the public name for callers that require a publish-ready job.
export const jobSchema = jobPublishSchema;

export const submissionSchema = z
  .object({
    model_used_text: trimmed(200),
    response_text: preservedRequired(500000),
    notes: z.string().trim().max(25000).default(''),
    reasoning_effort: z.enum(REASONING_EFFORTS),
    reasoning_effort_other: z.string().trim().max(200).default('')
  })
  .superRefine((data, context) => {
    if (data.reasoning_effort === 'other' && !data.reasoning_effort_other)
      context.addIssue({
        code: 'custom',
        path: ['reasoning_effort_other'],
        message: 'Specify the reasoning effort.'
      });
    if (data.reasoning_effort !== 'other' && data.reasoning_effort_other)
      context.addIssue({
        code: 'custom',
        path: ['reasoning_effort_other'],
        message: 'Only use this field when Other is selected.'
      });
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
export const adminDeleteInvitationSchema = z.object({ membership_id: uuid });
export const profileSchema = z.object({
  display_name: trimmed(120),
  bio: z.string().trim().max(2000).default(''),
  model_ids: z.array(uuid).max(PROFILE_MODELS.length).refine(unique, 'Choose each model once.'),
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
  if (!validUploadFilename(name)) return false;
  const ext = name.match(/\.([A-Za-z0-9]+)$/)?.[1]?.toLowerCase() ?? '';
  return size > 0 && size <= 25 * 1024 * 1024 && !!allowedFiles[ext]?.includes(mime);
}
export function validJobAttachmentZip(name: string, mime: string, size: number) {
  if (!validUploadFilename(name)) return false;
  const ext = name.match(/\.([A-Za-z0-9]+)$/)?.[1]?.toLowerCase() ?? '';
  return (
    ext === 'zip' &&
    ['application/zip', 'application/x-zip-compressed'].includes(mime) &&
    size > 0 &&
    size <= 25 * 1024 * 1024
  );
}
export function validProfilePhoto(name: string, mime: string, size: number) {
  if (!validFile(name, mime, size) || size > 5 * 1024 * 1024) return false;
  const ext = name.match(/\.([A-Za-z0-9]+)$/)?.[1]?.toLowerCase() ?? '';
  return ['png', 'jpg', 'jpeg', 'webp'].includes(ext);
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

function validUploadFilename(name: string) {
  return !(
    name.length < 1 ||
    name.length > 255 ||
    name !== name.trim() ||
    name.startsWith('.') ||
    name.includes('/') ||
    name.includes('\\') ||
    hasUnsafeAscii(name)
  );
}
