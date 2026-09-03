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
  safeFilename,
  safeReturnPath,
  totalFileSize,
  validExternalUrl,
  validFile,
  jobSchema,
  submissionSchema
} from './validation';
import { approvalEmailHref, claimExpired, controls, safeNotification, statusLabel } from './ui';
describe('handoff exports', () => {
  const job = { current_task: 'Continue analysis', success_criteria: 'A checked answer', output_format: 'Plain text' };
  it('generates bounded runnable prompt', () => {
    const p = runnablePrompt(
      job,
      [{ label: 'Prior', text_content: 'state' }],
      [{ original_filename: 'paper.pdf', description: 'read it' }]
    );
    expect(p).toContain('CURRENT TASK\nContinue analysis');
    expect(p).toContain('current task takes precedence');
    expect(p).toContain('paper.pdf: read it');
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
    expect(Object.keys(allowedFiles)).not.toContain('html');
  });
  it('caps aggregate sizes', () => expect(totalFileSize([{ size_bytes: 2 }, { size_bytes: 3 }])).toBe(5));
  it('rejects whitespace jobs', () => expect(jobSchema.safeParse({}).success).toBe(false));
  it('rejects unzoned deadlines and unsafe context links', () => {
    const base = {
      title: 'Task',
      listing_summary: 'Summary',
      current_task: 'Continue',
      success_criteria: 'Checked result',
      output_format: 'Text',
      visibility: 'claimed_only',
      sensitivity: 'unpublished',
      sensitivity_notes: '',
      effort: 'medium',
      preferred_model_id: '11111111-1111-4111-8111-111111111111',
      acceptable_model_ids: [],
      required_tools: [],
      prior_context: '',
      external_urls: [],
      acknowledged: true
    };
    expect(jobSchema.safeParse({ ...base, deadline: '2099-09-30T17:00:00' }).success).toBe(false);
    expect(jobSchema.safeParse({ ...base, deadline: '2099-09-30T17:00:00-04:00' }).success).toBe(true);
    expect(
      jobSchema.safeParse({ ...base, deadline: null, external_urls: ['https://user:secret@example.test/x'] }).success
    ).toBe(false);
  });
  it('parses form data without converting missing values to strings', () => {
    const form = new FormData();
    form.set('title', 'Task');
    form.set('listing_summary', 'Summary');
    form.set('current_task', '  Continue with indentation\n');
    form.set('success_criteria', 'Checked result');
    form.set('output_format', 'Text');
    form.set('visibility', 'claimed_only');
    form.set('sensitivity', 'general');
    form.set('effort', 'quick');
    form.set('preferred_model_id', '11111111-1111-4111-8111-111111111111');
    form.set('prior_context', 'Previous result');
    form.set('external_urls', 'https://drive.example/one\nhttps://drive.example/two');
    form.set('acknowledged', 'yes');
    const parsed = parseJobForm(form);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.input.current_task).toBe('  Continue with indentation\n');
      expect(parsed.input.contexts).toHaveLength(3);
    }
    expect(
      submissionSchema.safeParse({ model_used_text: null, response_text: null, notes: '', tools_used: [] }).success
    ).toBe(false);
  });
  it('validates model output without changing whitespace-significant content', () => {
    const response = '  indented first line\nnext line  \n';
    const parsed = submissionSchema.parse({
      model_used_text: 'Test model',
      response_text: response,
      notes: '',
      tools_used: []
    });
    expect(parsed.response_text).toBe(response);
    expect(
      submissionSchema.safeParse({ model_used_text: 'Test model', response_text: '   \n', notes: '', tools_used: [] })
        .success
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
  });

  it('encodes recipient delimiters instead of creating extra mail fields', () => {
    const href = approvalEmailHref('person@example.com?bcc=attacker@example.com');
    expect(href).toContain('person%40example.com%3Fbcc%3Dattacker%40example.com?subject=');
    expect(href.match(/\?/g)).toHaveLength(1);
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
    expect(login).toContain('Do not submit anything sensitive');
    expect(styles).toContain('--accent: #e77500;');
    expect(styles).not.toContain('--green:');
  });

  it('uses a human email label and offers a manual approval message for unclaimed invitations', () => {
    const admin = readFileSync(new URL('../routes/app/admin/+page.svelte', import.meta.url), 'utf8');
    expect(admin).toContain('<label>Email<input type="email" name="email" required /></label>');
    expect(admin).not.toContain('<label>Exact email');
    expect(admin).toContain('href={approvalEmailHref(m.invited_email)}');
    expect(admin).toContain('>Email approval</a');
  });
});
