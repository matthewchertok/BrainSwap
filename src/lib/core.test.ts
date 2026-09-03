import { describe, expect, it } from 'vitest';
import { contextMarkdown, followUpSnapshot, runnablePrompt } from './prompt';
import {
  allowedFiles,
  safeFilename,
  safeReturnPath,
  totalFileSize,
  validExternalUrl,
  validFile,
  jobSchema
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
    expect(safeReturnPath('//evil.test')).toBe('/app');
    expect(safeReturnPath('https://evil.test')).toBe('/app');
    expect(safeReturnPath('/\\evil')).toBe('/app');
  });
  it('validates URLs without fetching', () => {
    expect(validExternalUrl('https://drive.example/x')).toBe(true);
    expect(validExternalUrl('http://example.com')).toBe(false);
    expect(validExternalUrl('http://localhost:5000', true)).toBe(true);
  });
  it('sanitizes traversal and validates allowlist', () => {
    expect(safeFilename('../../bad name.PDF')).toBe('bad-name.pdf');
    expect(validFile('x.pdf', 'application/pdf', 12)).toBe(true);
    expect(validFile('x.svg', 'image/svg+xml', 12)).toBe(false);
    expect(Object.keys(allowedFiles)).not.toContain('html');
  });
  it('caps aggregate sizes', () => expect(totalFileSize([{ size_bytes: 2 }, { size_bytes: 3 }])).toBe(5));
  it('rejects whitespace jobs', () => expect(jobSchema.safeParse({}).success).toBe(false));
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
