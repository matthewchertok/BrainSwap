import { describe, expect, it } from 'vitest';
import { contextMarkdown, followUpSnapshot, runnablePrompt } from './prompt';
import { parseJobForm } from './server/job-form';
import { getSelectedMembership, type ActiveMembership } from './server/membership';
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
import { claimExpired, controls, safeNotification, statusLabel } from './ui';
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
