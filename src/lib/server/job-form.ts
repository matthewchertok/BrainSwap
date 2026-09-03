import { jobSchema } from '$lib/validation';

export function parseJobForm(form: FormData) {
  const deadline = text(form.get('deadline'));
  const localDeadline = text(form.get('deadline_local'));
  const parsed = jobSchema.safeParse({
    title: form.get('title'),
    listing_summary: form.get('listing_summary'),
    current_task: form.get('current_task'),
    success_criteria: form.get('success_criteria'),
    output_format: form.get('output_format'),
    visibility: form.get('visibility'),
    sensitivity: form.get('sensitivity'),
    sensitivity_notes: form.get('sensitivity_notes') ?? '',
    effort: form.get('effort'),
    // The browser converts datetime-local to an absolute instant. Fail validation
    // instead of silently dropping a selected deadline when that conversion is absent.
    deadline: deadline || (localDeadline ? 'invalid-local-deadline' : null),
    preferred_model_id: form.get('preferred_model_id'),
    acceptable_model_ids: form.getAll('acceptable_model_ids'),
    required_tools: form.getAll('required_tools'),
    prior_context: form.get('prior_context') ?? '',
    external_urls: text(form.get('external_urls'))
      .split(/\r?\n/)
      .map((value) => value.trim())
      .filter(Boolean),
    acknowledged: form.get('acknowledged') === 'yes'
  });
  if (!parsed.success) return parsed;
  const { prior_context, external_urls, ...input } = parsed.data;
  return {
    ...parsed,
    input: {
      ...input,
      contexts: [
        ...(prior_context ? [{ kind: 'inline_text', label: 'Prior context', text_content: prior_context }] : []),
        ...external_urls.map((url, index) => ({
          kind: 'external_link',
          label: `Reference link ${index + 1}`,
          url
        }))
      ]
    }
  };
}

function text(value: FormDataEntryValue | null) {
  return typeof value === 'string' ? value.trim() : '';
}
