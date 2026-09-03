export function claimExpired(at: string | null, now = Date.now()) {
  return !!at && new Date(at).getTime() <= now;
}
export function statusLabel(s: string) {
  return (
    ({ revision_requested: 'Revision requested', claimed: 'In progress' } as Record<string, string>)[s] ??
    s.charAt(0).toUpperCase() + s.slice(1).replaceAll('_', ' ')
  );
}
export function notificationStatus(type: string) {
  return (
    (
      {
        new_job: 'open',
        job_claimed: 'claimed',
        result_submitted: 'submitted',
        revision_requested: 'revision_requested',
        job_accepted: 'accepted',
        job_cancelled: 'cancelled'
      } as Record<string, string>
    )[type] ?? type
  );
}
export function notificationLabel(type: string) {
  return (
    (
      {
        new_job: 'New job',
        job_claimed: 'Claimed',
        result_submitted: 'Submitted',
        revision_requested: 'Revision',
        job_accepted: 'Accepted',
        job_cancelled: 'Cancelled'
      } as Record<string, string>
    )[type] ?? statusLabel(type)
  );
}
export function controls(role: 'requester' | 'helper' | 'admin' | 'member', status: string) {
  return {
    accept: role === 'requester' && status === 'submitted',
    revise: role === 'requester' && status === 'submitted',
    claim: ['helper', 'admin', 'member'].includes(role) && ['open', 'revision_requested'].includes(status),
    cancel: ['requester', 'admin'].includes(role) && status !== 'accepted'
  };
}
export function safeNotification(type: string, title: string) {
  return { type, message: `${type.replaceAll('_', ' ')}: ${title.slice(0, 120)}` };
}

export function approvalEmailHref(recipient: string) {
  const subject = encodeURIComponent('BrainSwap access approved');
  const body = encodeURIComponent('Hello,\n\nYour BrainSwap access request has been approved.');
  return `mailto:${encodeURIComponent(recipient)}?subject=${subject}&body=${body}`;
}

export function membershipHeading(displayName: string | null, invitedEmail: string) {
  return displayName?.trim() || invitedEmail;
}

export function dateTimeLocalToIso(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return '';
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime()) || isoToDateTimeLocal(instant.toISOString()) !== value) return '';
  return instant.toISOString();
}

export function isoToDateTimeLocal(value: string | null, offsetMinutes?: number) {
  if (!value) return '';
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) return '';
  const offset = offsetMinutes ?? instant.getTimezoneOffset();
  if (!Number.isFinite(offset)) return '';
  return new Date(instant.getTime() - offset * 60_000).toISOString().slice(0, 16);
}
