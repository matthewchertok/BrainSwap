export function claimExpired(at: string | null, now = Date.now()) {
  return !!at && new Date(at).getTime() <= now;
}
export function statusLabel(s: string) {
  return (
    ({ revision_requested: 'Revision requested', claimed: 'In progress' } as Record<string, string>)[s] ??
    s.charAt(0).toUpperCase() + s.slice(1).replaceAll('_', ' ')
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
  const query = new URLSearchParams({
    subject: 'BrainSwap access approved',
    body: 'Hello,\n\nYour BrainSwap access request has been approved.'
  });
  return `mailto:${encodeURIComponent(recipient)}?${query.toString()}`;
}
