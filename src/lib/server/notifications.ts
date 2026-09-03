import { env } from '$env/dynamic/private';
type Notice = { type: string; jobId: string; organizationId: string };
export async function sendMetadataWebhook(notice: Notice) {
  if (!env.NOTIFICATION_WEBHOOK_URL) return;
  try {
    await fetch(env.NOTIFICATION_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(notice),
      signal: AbortSignal.timeout(3000)
    });
  } catch {
    // A committed workflow must never fail because optional delivery failed.
  }
}
