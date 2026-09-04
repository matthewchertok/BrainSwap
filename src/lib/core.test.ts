import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import svelteConfig from '../../svelte.config.js';
import { contextMarkdown, followUpSnapshot, runnablePrompt } from './prompt';
import {
  accessRequestEmailBody,
  accessRequestIdempotencyKey,
  deliverAccessRequestEmail,
  verifiedPrimaryGoogleEmail,
  type AccessRequestEmailSettings
} from './server/access-request-email';
import { parseJobForm } from './server/job-form';
import { getSelectedMembership, type ActiveMembership } from './server/membership';
import { applyBaselineSecurityHeaders } from './server/security-headers';
import {
  allowedFiles,
  jobDraftSchema,
  jobPublishSchema,
  PROFILE_MODELS,
  REASONING_EFFORTS,
  safeFilename,
  safeReturnPath,
  totalFileSize,
  validExternalUrl,
  validFile,
  validJobAttachmentZip,
  validProfilePhoto,
  jobSchema,
  submissionSchema
} from './validation';
import { AUTH_COOKIE_MAX_AGE_SECONDS, authCookieOptions } from './auth-session';
import {
  approvalEmailHref,
  claimExpired,
  controls,
  dateTimeLocalToIso,
  isoToDateTimeLocal,
  membershipHeading,
  safeNotification,
  statusLabel
} from './ui';

function completeJobForm() {
  const form = new FormData();
  form.set('title', 'Task');
  form.set('task_summary', 'Summary');
  form.set('prompt', '  Continue with indentation\n');
  form.set('chat_url', 'https://chat.example/share/one');
  form.set('preferred_model_text', 'GPT-6 Astra');
  form.set('acceptable_models_text', 'Any frontier model');
  return form;
}

describe('handoff exports', () => {
  const job = { prompt: 'Continue analysis and return a checked answer.' };
  it('generates bounded runnable prompt', () => {
    const p = runnablePrompt(
      { ...job, helper_instructions: 'Unzip materials.zip before starting.' },
      [{ label: 'Link to chat', url: 'https://chat.example/share/one' }],
      [{ original_filename: 'paper.pdf', description: 'read it' }]
    );
    expect(p).toContain('Study the full chat history');
    expect(p).toContain('PROMPT\nContinue analysis');
    expect(p).toContain('INSTRUCTIONS FOR THE HELPER\nUnzip materials.zip before starting.');
    expect(p).toContain('paper.pdf: read it');
  });
  it('keeps legacy and follow-up context separate from the new prompt', () => {
    const p = runnablePrompt(
      { prompt: 'Run the next calculation.', legacy_current_task: 'Legacy exact task.' },
      [{ kind: 'previous_job', label: 'Prior result', text_content: 'Earlier finalized answer.' }],
      []
    );
    expect(p).toContain('LEGACY TASK DETAILS\nLegacy exact task.');
    expect(p).toContain('PRIOR FINALIZED RESULT\nEarlier finalized answer.');
    expect(p).toContain('PROMPT\nRun the next calculation.');
  });
  it('creates context markdown and safe snapshot', () => {
    expect(contextMarkdown(job, [], [])).toMatch(/^# BrainSwap handoff/);
    expect(followUpSnapshot('result').text_content).toBe('result');
  });
});
describe('validation', () => {
  it('allows safe returns only', () => {
    expect(safeReturnPath('/app/jobs/1')).toBe('/app/jobs/1');
    expect(safeReturnPath('/app/jobs/1?tab=review#result')).toBe('/app/jobs/1?tab=review#result');
    expect(safeReturnPath('//evil.test')).toBe('/app');
    expect(safeReturnPath('https://evil.test')).toBe('/app');
    expect(safeReturnPath('/\\evil')).toBe('/app');
    expect(safeReturnPath('/\t/evil.test')).toBe('/app');
    expect(safeReturnPath('/\n/evil.test')).toBe('/app');
    expect(safeReturnPath('/\r/evil.test')).toBe('/app');
    expect(safeReturnPath('/%5c%5cevil.test')).toBe('/app');
    expect(safeReturnPath('/login')).toBe('/app');
    expect(safeReturnPath('/application')).toBe('/app');
  });
  it('validates URLs without fetching', () => {
    expect(validExternalUrl('https://drive.example/x')).toBe(true);
    expect(validExternalUrl('http://example.com')).toBe(false);
    expect(validExternalUrl('http://localhost:5000')).toBe(false);
    expect(validExternalUrl('https://user:secret@drive.example/x')).toBe(false);
    expect(validExternalUrl('https://[::1]/x')).toBe(false);
    expect(validExternalUrl('https://999.1.1.1/x')).toBe(false);
    expect(validExternalUrl('https://bad_host.example/x')).toBe(false);
    expect(validExternalUrl('javascript:alert(1)')).toBe(false);
  });
  it('sanitizes traversal and validates allowlist', () => {
    expect(safeFilename('../../bad name.PDF')).toBe('bad-name.pdf');
    expect(validFile('x.pdf', 'application/pdf', 12)).toBe(true);
    expect(validFile('../../x.pdf', 'application/pdf', 12)).toBe(false);
    expect(validFile('.hidden.pdf', 'application/pdf', 12)).toBe(false);
    expect(validFile('x\u0000.pdf', 'application/pdf', 12)).toBe(false);
    expect(validFile('x.svg', 'image/svg+xml', 12)).toBe(false);
    expect(validProfilePhoto('portrait.webp', 'image/webp', 12)).toBe(true);
    expect(validProfilePhoto('paper.pdf', 'application/pdf', 12)).toBe(false);
    expect(validProfilePhoto('portrait.png', 'image/png', 6 * 1024 * 1024)).toBe(false);
    expect(validJobAttachmentZip('materials.zip', 'application/zip', 12)).toBe(true);
    expect(validJobAttachmentZip('materials.pdf', 'application/pdf', 12)).toBe(false);
    expect(validJobAttachmentZip('materials.zip', 'application/zip', 25 * 1024 * 1024 + 1)).toBe(false);
    expect(Object.keys(allowedFiles)).not.toContain('html');
  });
  it('caps aggregate sizes', () => expect(totalFileSize([{ size_bytes: 2 }, { size_bytes: 3 }])).toBe(5));
  it('rejects whitespace jobs', () => expect(jobSchema.safeParse({}).success).toBe(false));
  it('rejects unzoned deadlines and unsafe context links', () => {
    const base = {
      title: 'Task',
      task_summary: 'Summary',
      prompt: 'Continue',
      helper_instructions: '',
      chat_url: 'https://chat.example/share/one',
      preferred_model_text: 'GPT-6 Astra',
      acceptable_models_text: 'Any frontier model'
    };
    expect(jobSchema.safeParse({ ...base, deadline: '2099-09-30T17:00:00' }).success).toBe(false);
    expect(jobSchema.safeParse({ ...base, deadline: '2099-09-30T17:00:00-04:00' }).success).toBe(true);
    expect(
      jobSchema.safeParse({ ...base, deadline: null, chat_url: 'https://user:secret@example.test/x' }).success
    ).toBe(false);
  });
  it('allows incomplete drafts but requires complete published jobs', () => {
    const empty = {
      title: '',
      task_summary: '',
      prompt: '',
      helper_instructions: '',
      chat_url: '',
      preferred_model_text: '',
      acceptable_models_text: '',
      deadline: null
    };
    expect(jobDraftSchema.safeParse(empty).success).toBe(true);
    expect(jobPublishSchema.safeParse(empty).success).toBe(false);
    expect(
      jobPublishSchema.safeParse({
        ...empty,
        title: 'Task',
        task_summary: 'Summary',
        prompt: 'Prompt',
        preferred_model_text: 'GPT-6 Astra'
      }).success
    ).toBe(false);
    expect(jobDraftSchema.safeParse({ ...empty, prompt: 'p'.repeat(100000) }).success).toBe(true);
    expect(jobDraftSchema.safeParse({ ...empty, prompt: 'p'.repeat(100001) }).success).toBe(false);
  });
  it('parses form data without converting missing values to strings', () => {
    const form = completeJobForm();
    const parsed = parseJobForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.input.prompt).toBe('  Continue with indentation\n');
      expect(parsed.input.chat_url).toBe('https://chat.example/share/one');
    }
    expect(
      submissionSchema.safeParse({
        model_used_text: null,
        response_text: null,
        notes: '',
        reasoning_effort: 'medium',
        reasoning_effort_other: ''
      }).success
    ).toBe(false);
  });
  it('validates model output without changing whitespace-significant content', () => {
    const response = '  indented first line\nnext line  \n';
    const parsed = submissionSchema.parse({
      model_used_text: 'Test model',
      response_text: response,
      notes: '',
      reasoning_effort: 'high',
      reasoning_effort_other: ''
    });
    expect(parsed.response_text).toBe(response);
    expect(
      submissionSchema.safeParse({
        model_used_text: 'Test model',
        response_text: '   \n',
        notes: '',
        reasoning_effort: 'high',
        reasoning_effort_other: ''
      }).success
    ).toBe(false);
    expect(
      submissionSchema.safeParse({
        model_used_text: 'Test model',
        response_text: 'Done',
        notes: '',
        reasoning_effort: 'other',
        reasoning_effort_other: ''
      }).success
    ).toBe(false);
  });
});
describe('display and decisions', () => {
  it('calculates expiry', () => {
    expect(claimExpired('2000-01-01T00:00:00Z')).toBe(true);
    expect(claimExpired(null)).toBe(false);
  });
  it('labels state and scopes controls', () => {
    expect(statusLabel('revision_requested')).toBe('Revision requested');
    expect(controls('requester', 'submitted').accept).toBe(true);
    expect(controls('member', 'submitted').accept).toBe(false);
  });
  it('uses the invited email when a member has no display name', () => {
    expect(membershipHeading(null, 'claimed@example.com')).toBe('claimed@example.com');
    expect(membershipHeading('Member Name', 'claimed@example.com')).toBe('Member Name');
  });
  it('keeps notifications metadata-sized', () =>
    expect(safeNotification('job_claimed', 'x'.repeat(500)).message.length).toBeLessThan(150));
});

describe('organization selection', () => {
  const memberships: ActiveMembership[] = [
    {
      organization_id: '11111111-1111-4111-8111-111111111111',
      membership_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      organization_name: 'One',
      display_name: null,
      role: 'member',
      capabilities: [],
      notification_preferences: {}
    },
    {
      organization_id: '22222222-2222-4222-8222-222222222222',
      membership_id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      organization_name: 'Two',
      display_name: 'Member',
      role: 'admin',
      capabilities: [],
      notification_preferences: { new_matching_jobs: true }
    }
  ];

  it('accepts only a live membership organization', () => {
    expect(getSelectedMembership({ get: () => memberships[1]!.organization_id }, memberships)).toEqual(memberships[1]);
    expect(getSelectedMembership({ get: () => '33333333-3333-4333-8333-333333333333' }, memberships)).toBeNull();
  });
});

describe('security headers', () => {
  it('preserves CSRF-compatible same-origin forms without leaking referrers off-site', () => {
    const headers = new Headers();
    applyBaselineSecurityHeaders(headers);
    expect(headers.get('Referrer-Policy')).toBe('same-origin');
    expect(headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(headers.get('X-Frame-Options')).toBe('DENY');
    expect(headers.get('Permissions-Policy')).toBe('camera=(), microphone=(), geolocation=()');
  });

  it('keeps the document referrer policy aligned with the response header', () => {
    const appTemplate = readFileSync(new URL('../app.html', import.meta.url), 'utf8');
    expect(appTemplate).toContain('<meta name="referrer" content="same-origin" />');
    expect(appTemplate).not.toContain('<meta name="referrer" content="no-referrer" />');
  });

  it('allows only the required OAuth form redirect origins in CSP', () => {
    const supabaseOrigin = new URL(process.env.PUBLIC_SUPABASE_URL!).origin;
    expect(svelteConfig.kit.csp.directives['form-action']).toEqual([
      'self',
      supabaseOrigin,
      'https://accounts.google.com'
    ]);
  });
});

describe('access request email', () => {
  const settings: AccessRequestEmailSettings = {
    apiKey: 'test-only-api-key',
    recipient: 'operator@example.com',
    sender: 'notifications@example.com'
  };

  it('uses the verified email in a minimal plain-text message', () => {
    expect(accessRequestEmailBody(' Requester@Example.com ')).toBe(
      'requester@example.com is requesting access to BrainSwap.'
    );
    expect(accessRequestEmailBody('not-an-email')).toBeNull();
  });

  it('accepts only a confirmed primary Google identity', () => {
    expect(
      verifiedPrimaryGoogleEmail({
        email: ' Requester@Example.com ',
        email_confirmed_at: '2026-09-03T00:00:00Z',
        app_metadata: { provider: 'google' }
      })
    ).toBe('requester@example.com');
    expect(
      verifiedPrimaryGoogleEmail({
        email: 'requester@example.com',
        email_confirmed_at: '2026-09-03T00:00:00Z',
        app_metadata: { provider: 'github' }
      })
    ).toBeNull();
    expect(
      verifiedPrimaryGoogleEmail({ email: 'requester@example.com', app_metadata: { provider: 'google' } })
    ).toBeNull();
  });

  it('creates a stable hashed idempotency key without exposing the email', async () => {
    const first = await accessRequestIdempotencyKey('requester@example.com', settings);
    const retry = await accessRequestIdempotencyKey('requester@example.com', settings);
    expect(first).toBe(retry);
    expect(first).not.toContain('requester');
    expect(first.length).toBeLessThan(256);
  });

  it('sends only the bounded message with a server-side key', async () => {
    let capturedUrl = '';
    let capturedInit: RequestInit | undefined;
    const fetcher = (async (input: URL | RequestInfo, init?: RequestInit) => {
      capturedUrl = String(input);
      capturedInit = init;
      return new Response(JSON.stringify({ id: 'test-message-id' }), { status: 200 });
    }) as typeof fetch;

    await expect(deliverAccessRequestEmail('requester@example.com', settings, { fetcher })).resolves.toBe('sent');

    const headers = new Headers(capturedInit?.headers);
    const payload = JSON.parse(String(capturedInit?.body));
    expect(capturedUrl).toBe('https://api.resend.com/emails');
    expect(capturedInit?.method).toBe('POST');
    expect(headers.get('authorization')).toBe('Bearer test-only-api-key');
    expect(headers.get('idempotency-key')).toMatch(/^brainswap-access\/[0-9a-f]{64}$/);
    expect(payload).toEqual({
      from: 'BrainSwap <notifications@example.com>',
      to: ['operator@example.com'],
      subject: 'BrainSwap access request',
      text: 'requester@example.com is requesting access to BrainSwap.'
    });
  });

  it('rejects invalid email data before attempting delivery', async () => {
    let called = false;
    const fetcher = (async () => {
      called = true;
      return new Response(null, { status: 200 });
    }) as typeof fetch;
    await expect(deliverAccessRequestEmail('invalid', settings, { fetcher })).resolves.toBe('failed');
    expect(called).toBe(false);
  });
});

describe('approval email link', () => {
  it('prefills a bounded plain-text approval message without sending it', () => {
    const href = approvalEmailHref('person@example.com');
    const [recipient, query] = href.slice('mailto:'.length).split('?', 2);
    const params = new URLSearchParams(query);

    expect(decodeURIComponent(recipient)).toBe('person@example.com');
    expect(params.get('subject')).toBe('BrainSwap access approved');
    expect(params.get('body')).toBe('Hello,\n\nYour BrainSwap access request has been approved.');
    expect(href).not.toContain('+');
  });

  it('encodes recipient delimiters instead of creating extra mail fields', () => {
    const href = approvalEmailHref('person@example.com?bcc=attacker@example.com');
    expect(href).toContain('person%40example.com%3Fbcc%3Dattacker%40example.com?subject=');
    expect(href.match(/\?/g)).toHaveLength(1);
  });
});

describe('deadline picker conversion', () => {
  it('converts an absolute deadline to a local calendar value with an explicit test offset', () => {
    expect(isoToDateTimeLocal('2099-09-30T21:00:00.000Z', 240)).toBe('2099-09-30T17:00');
  });

  it('converts a valid local calendar value to an absolute ISO timestamp', () => {
    const value = '2099-09-30T17:00';
    expect(dateTimeLocalToIso(value)).toBe(new Date(value).toISOString());
    expect(dateTimeLocalToIso('')).toBe('');
    expect(dateTimeLocalToIso('not-a-date')).toBe('');
  });

  it('fails closed when a selected local deadline lacks browser timezone conversion', () => {
    const form = completeJobForm();
    form.set('deadline_local', '2099-09-30T17:00');
    expect(parseJobForm(form).success).toBe(false);
  });

  it('accepts the browser-converted absolute deadline', () => {
    const form = completeJobForm();
    const local = '2099-09-30T17:00';
    const absolute = dateTimeLocalToIso(local);
    form.set('deadline_local', local);
    form.set('deadline', absolute);
    const parsed = parseJobForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.input.deadline).toBe(absolute);
  });
});

describe('UI feedback contracts', () => {
  it('keeps dashboard tab navigation visibly and accessibly pending', () => {
    const dashboard = readFileSync(new URL('../routes/app/+page.svelte', import.meta.url), 'utf8');
    expect(dashboard).toContain("import { navigating } from '$app/state'");
    expect(dashboard).toContain('role="status" aria-live="polite"');
    expect(dashboard).toContain('class:pending={pendingTab !== null}');
  });

  it('uses versioned login copy, a POST access request, and the requested accent', () => {
    const login = readFileSync(new URL('../routes/login/+page.svelte', import.meta.url), 'utf8');
    const styles = readFileSync(new URL('../app.css', import.meta.url), 'utf8');
    expect(login).toContain('<p class="eyebrow">{brand.version}</p>');
    expect(login).toContain('<form method="POST" action="?/requestAccess">');
    expect(login).not.toContain('Data boundary:');
    expect(login).not.toContain('Do not submit anything sensitive');
    expect(styles).toContain('--accent: #e77500;');
    expect(styles).not.toContain('--green:');
  });

  it('persists browser sessions and renews a durable auth cookie', () => {
    const browserClient = readFileSync(new URL('./supabase-browser.ts', import.meta.url), 'utf8');
    const serverHook = readFileSync(new URL('../hooks.server.ts', import.meta.url), 'utf8');
    expect(browserClient).toContain('persistSession: true');
    expect(browserClient).toContain('autoRefreshToken: true');
    expect(browserClient).toContain('cookieOptions: authCookieOptions');
    expect(serverHook).toContain('cookieOptions: authCookieOptions');
    expect(AUTH_COOKIE_MAX_AGE_SECONDS).toBe(400 * 24 * 60 * 60);
    expect(authCookieOptions(true)).toEqual({
      path: '/',
      sameSite: 'lax',
      secure: true,
      maxAge: AUTH_COOKIE_MAX_AGE_SECONDS
    });
  });

  it('uses a human email label and offers a manual approval message for unclaimed invitations', () => {
    const admin = readFileSync(new URL('../routes/app/admin/+page.svelte', import.meta.url), 'utf8');
    expect(admin).toContain('<label>Email<input type="email" name="email" required /></label>');
    expect(admin).not.toContain('<label>Exact email');
    expect(admin).toContain('href={approvalEmailHref(m.invited_email)}');
    expect(admin).toContain('>Email approval</a');
    expect(admin).toContain('{#if m.active}<a');
  });

  it('uses native local date-time controls and non-interactive job status indicators', () => {
    const newJob = readFileSync(new URL('../routes/app/jobs/new/+page.svelte', import.meta.url), 'utf8');
    const detail = readFileSync(new URL('../routes/app/jobs/[id]/+page.svelte', import.meta.url), 'utf8');
    const status = readFileSync(new URL('./components/JobStatus.svelte', import.meta.url), 'utf8');
    const styles = readFileSync(new URL('../app.css', import.meta.url), 'utf8');
    expect(newJob).toContain('type="datetime-local"');
    expect(detail).toContain('type="datetime-local"');
    expect(newJob).not.toContain('ISO 8601 timestamp');
    expect(detail).toContain('<JobStatus status={w.job.status} />');
    expect(status).toContain("class:is-open={status === 'open'}");
    expect(status).toContain("status === 'submitted' || status === 'accepted'");
    expect(status).not.toContain('<button');
    expect(styles).toContain('.job-status.is-open .job-status-dot');
    expect(styles).toContain('background: #e2aa00;');
    expect(styles).toContain('.job-status.is-success .job-status-dot');
    expect(styles).toContain('background: #38a169;');
  });

  it('distinguishes a published job from a saved draft in the confirmation copy', () => {
    const createAction = readFileSync(new URL('../routes/app/jobs/new/+page.server.ts', import.meta.url), 'utf8');
    const detailLoad = readFileSync(new URL('../routes/app/jobs/[id]/+page.server.ts', import.meta.url), 'utf8');
    expect(createAction).toContain('redirect(303, `/app/jobs/${id.data}?published=1`)');
    expect(detailLoad).toContain("if (params.has('published')) return 'Job published.';");
  });

  it('keeps the simplified job form and free-form model preferences', () => {
    const newJob = readFileSync(new URL('../routes/app/jobs/new/+page.svelte', import.meta.url), 'utf8');
    const detail = readFileSync(new URL('../routes/app/jobs/[id]/+page.svelte', import.meta.url), 'utf8');
    const detailActions = readFileSync(new URL('../routes/app/jobs/[id]/+page.server.ts', import.meta.url), 'utf8');
    expect(newJob).toContain('name="task_summary"');
    expect(newJob).toContain('name="prompt"');
    expect(newJob).toContain('name="chat_url"');
    expect(newJob).not.toContain('Link to chat (optional)');
    expect(newJob).toContain('name="helper_instructions"');
    expect(newJob).toContain('name="job_attachment"');
    expect(newJob).toContain('accept=".zip,application/zip,application/x-zip-compressed"');
    expect(newJob).toContain('placeholder="The name of this task"');
    expect(newJob).toContain('placeholder="A brief description of what this task is about"');
    expect(newJob).toContain('placeholder="The complete instruction set for the helper to give their model"');
    expect(newJob).toContain('name="preferred_model_text"');
    expect(newJob).toContain('placeholder="GPT-6 Astra"');
    expect(newJob).toContain('name="acceptable_models_text"');
    expect(newJob).toContain('placeholder="Any frontier model"');
    expect(newJob).toContain('name="intent" value="draft"');
    expect(newJob).not.toContain('name="visibility"');
    expect(newJob).not.toContain('name="sensitivity"');
    expect(newJob).not.toContain('name="effort"');
    expect(newJob).not.toContain('name="acknowledged"');
    expect(newJob).not.toContain('name="output_format"');
    expect(newJob).not.toContain('name="required_tools"');
    expect(newJob).toContain('maxlength="100000"');
    expect(detail).toContain('form="draft-editor" name="intent" value="publish"');
    expect(detailActions).toContain("intent.data === 'publish' ? 'update_and_publish_job' : 'update_draft_job'");
  });

  it('supports editable submitted results, reasoning effort, and live file tables', () => {
    const detail = readFileSync(new URL('../routes/app/jobs/[id]/+page.svelte', import.meta.url), 'utf8');
    const detailActions = readFileSync(new URL('../routes/app/jobs/[id]/+page.server.ts', import.meta.url), 'utf8');
    expect(detail).toContain("w.permissions.edit_submission ? '?/edit_submission' : '?/submit'");
    expect(detail).toContain('<legend>Reasoning effort</legend>');
    expect(detail).toContain('<h2>Required attachments</h2>');
    expect(detail).toContain('<h2>Attach result files</h2>');
    expect(detail).toContain('<table class="file-table">');
    expect(detail).toContain('bind:value={draftPrompt}');
    expect(detail).toContain('bind:value={resultResponse}');
    expect(detail).toContain('>Uploading</td');
    expect(detail).toContain('{#if w.permissions.copy_prompt}');
    expect(detail).not.toContain('name="tools_used"');
    expect(detail).not.toContain('Sealed task');
    expect(detail).toContain("w.permissions.cancel && w.job.status !== 'cancelled'");
    expect(detailActions).toContain('edit_submission: async');
    expect(detailActions).toContain("locals.supabase.rpc('edit_submitted_result'");
    expect(REASONING_EFFORTS).toEqual(['low', 'medium', 'high', 'extra_high', 'max', 'ultra', 'other']);
  });

  it('uses the fixed profile catalog and removes capabilities and admin model management', () => {
    const profile = readFileSync(new URL('../routes/app/profile/+page.svelte', import.meta.url), 'utf8');
    const profileServer = readFileSync(new URL('../routes/app/profile/+page.server.ts', import.meta.url), 'utf8');
    const admin = readFileSync(new URL('../routes/app/admin/+page.svelte', import.meta.url), 'utf8');
    expect(PROFILE_MODELS).toEqual([
      'GPT-6 Astra',
      'GPT-5.6 Sol',
      'GPT-5.6 Terra',
      'GPT-5.6 Luna',
      'Claude Fable 5.1',
      'Claude Opus 5',
      'Gemini Pro',
      'SuperGrok'
    ]);
    expect(profile).toContain('<h2>Profile photo</h2>');
    expect(profile).toContain('{#if data.photo}<button');
    expect(profile).toContain('action="?/upload_photo" enctype="multipart/form-data"');
    expect(profile).not.toContain('cleanupPhoto(data.photo.id, false)');
    expect(profileServer).toContain('upload_photo: async');
    expect(profileServer).toContain('save: async');
    expect(profileServer).not.toContain('default: async');
    expect(profileServer).toContain(".from('profile-photos')");
    expect(profileServer).toContain('.upload(reservation.storage_path, photo');
    expect(profile).toContain('<form method="POST" action="?/save" class="panel profile-form">');
    expect(profile).toContain('name="bio"');
    expect(profile).toContain('Organization<select disabled');
    expect(profile).not.toContain('name="capabilities"');
    expect(admin).not.toContain('<h2>Models</h2>');
    expect(admin).toContain('action="?/delete_invitation"');
  });

  it('uses the white workspace and dark navigation banner without the old warning strip', () => {
    const layout = readFileSync(new URL('../routes/app/+layout.svelte', import.meta.url), 'utf8');
    const styles = readFileSync(new URL('../app.css', import.meta.url), 'utf8');
    expect(layout).not.toContain('Not approved for Restricted');
    expect(styles).toContain('background: #121212;');
    expect(styles).toContain('background: #fff;');
    expect(styles).toContain('background: var(--accent);');
  });

  it('preserves pre-migration requester responses as result edit locks', () => {
    const migration = readFileSync(
      new URL('../../supabase/migrations/202609030003_workflow_overhaul.sql', import.meta.url),
      'utf8'
    );
    expect(migration).toContain('with prior_follow_ups as (');
    expect(migration).toContain(
      'set requester_action_at = coalesce(parent.requester_action_at, follow_up.responded_at)'
    );
    expect(migration).toContain('set edit_locked_at = coalesce(submission.edit_locked_at, parent.requester_action_at)');
  });

  it('authorizes profile uploads using the live Storage preflight metadata shape', () => {
    const migration = readFileSync(
      new URL('../../supabase/migrations/202609030005_profile_photo_storage_preflight.sql', import.meta.url),
      'utf8'
    );
    expect(migration).toContain("p_metadata ->> 'mimetype'");
    expect(migration).toContain("private bucket's 5 MiB file limit");
    expect(migration).toContain('finalize_profile_photo verify');
    expect(migration).toContain('grant execute on function private.can_profile_photo_storage_upload');
  });
});
