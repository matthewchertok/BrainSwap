import { env } from '$env/dynamic/private';
import { z } from 'zod';

const emailSchema = z.string().trim().toLowerCase().max(254).email();
const authUserIdSchema = z.string().uuid();

const settingsSchema = z.object({
  apiKey: z.string().trim().min(1).max(512),
  recipient: emailSchema,
  sender: emailSchema
});

export type AccessRequestEmailSettings = z.infer<typeof settingsSchema>;
export type AccessRequestEmailResult = 'sent' | 'failed' | 'not_configured';

type AccessRequestAuthUser = {
  email?: string;
  email_confirmed_at?: string;
  app_metadata?: { provider?: unknown };
};

type DeliveryOptions = {
  fetcher?: typeof fetch;
};

export function accessRequestEmailSettings(): AccessRequestEmailSettings | null {
  const parsed = settingsSchema.safeParse({
    apiKey: env.RESEND_API_KEY,
    recipient: env.ACCESS_REQUEST_EMAIL_TO,
    sender: env.ACCESS_REQUEST_EMAIL_FROM
  });
  return parsed.success ? parsed.data : null;
}

export function accessRequestEmailBody(requesterEmail: string): string | null {
  const parsed = emailSchema.safeParse(requesterEmail);
  return parsed.success ? `${parsed.data} is requesting access to BrainSwap.` : null;
}

export function verifiedPrimaryGoogleEmail(user: AccessRequestAuthUser | null): string | null {
  if (!user?.email_confirmed_at || user.app_metadata?.provider !== 'google') return null;
  const parsed = emailSchema.safeParse(user.email);
  return parsed.success ? parsed.data : null;
}

export async function accessRequestIdempotencyKey(
  requesterEmail: string,
  authUserId: string,
  settings: AccessRequestEmailSettings
): Promise<string> {
  const normalizedRequester = emailSchema.parse(requesterEmail);
  const normalizedAuthUserId = authUserIdSchema.parse(authUserId);
  const normalizedSettings = settingsSchema.parse(settings);
  const material = `${normalizedRequester}\u0000${normalizedAuthUserId}\u0000${normalizedSettings.recipient}\u0000${normalizedSettings.sender}`;
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(material));
  const hash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
  return `brainswap-access/${hash}`;
}

export async function deliverAccessRequestEmail(
  requesterEmail: string,
  authUserId: string,
  unparsedSettings: AccessRequestEmailSettings,
  { fetcher = fetch }: DeliveryOptions = {}
): Promise<AccessRequestEmailResult> {
  const settings = settingsSchema.safeParse(unparsedSettings);
  const body = accessRequestEmailBody(requesterEmail);
  const parsedAuthUserId = authUserIdSchema.safeParse(authUserId);
  if (!settings.success || !body || !parsedAuthUserId.success) return 'failed';

  try {
    const normalizedRequester = emailSchema.parse(requesterEmail);
    const idempotencyKey = await accessRequestIdempotencyKey(normalizedRequester, parsedAuthUserId.data, settings.data);
    const response = await fetcher('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${settings.data.apiKey}`,
        'content-type': 'application/json',
        'idempotency-key': idempotencyKey,
        'user-agent': 'BrainSwap/0.1'
      },
      body: JSON.stringify({
        from: `BrainSwap <${settings.data.sender}>`,
        to: [settings.data.recipient],
        subject: 'BrainSwap access request',
        text: body
      }),
      signal: AbortSignal.timeout(5000)
    });
    return response.ok ? 'sent' : 'failed';
  } catch {
    return 'failed';
  }
}

export async function sendAccessRequestEmail(
  requesterEmail: string,
  authUserId: string,
  options: DeliveryOptions = {}
): Promise<AccessRequestEmailResult> {
  const settings = accessRequestEmailSettings();
  if (!settings) return 'not_configured';
  return deliverAccessRequestEmail(requesterEmail, authUserId, settings, options);
}
