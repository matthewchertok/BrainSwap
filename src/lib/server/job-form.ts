import { jobDraftSchema, jobIntentSchema, jobPublishSchema } from '$lib/validation';
import type { z } from 'zod';

type JobIntent = z.infer<typeof jobIntentSchema>;

export function parseJobForm(form: FormData, intent: JobIntent = 'publish') {
  const deadline = text(form.get('deadline'));
  const localDeadline = text(form.get('deadline_local'));
  const schema = intent === 'draft' ? jobDraftSchema : jobPublishSchema;
  const parsed = schema.safeParse({
    title: form.get('title'),
    task_summary: form.get('task_summary'),
    prompt: form.get('prompt'),
    helper_instructions: form.get('helper_instructions') ?? '',
    chat_url: form.get('chat_url') ?? '',
    preferred_model_text: form.get('preferred_model_text'),
    acceptable_models_text: form.get('acceptable_models_text'),
    // The browser converts datetime-local to an absolute instant. Fail validation
    // instead of silently dropping a selected deadline when that conversion is absent.
    deadline: deadline || (localDeadline ? 'invalid-local-deadline' : null)
  });
  if (!parsed.success) return parsed;
  return { ...parsed, input: parsed.data };
}

function text(value: FormDataEntryValue | null) {
  return typeof value === 'string' ? value.trim() : '';
}
