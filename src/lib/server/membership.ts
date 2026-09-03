import { error, redirect, type Cookies } from '@sveltejs/kit';
import { z } from 'zod';

const activeMembershipSchema = z.object({
  organization_id: z.string().uuid(),
  membership_id: z.string().uuid(),
  organization_name: z.string().min(1),
  display_name: z.string().nullable(),
  role: z.enum(['member', 'admin']),
  capabilities: z.array(z.string()),
  notification_preferences: z.object({ new_matching_jobs: z.boolean().optional() }).passthrough()
});

export type ActiveMembership = z.infer<typeof activeMembershipSchema>;

const ORGANIZATION_COOKIE = 'brainswap_org';

export async function getActiveMemberships(locals: App.Locals): Promise<ActiveMembership[]> {
  const { data, error: membershipError } = await locals.supabase.rpc('my_active_memberships');
  if (membershipError) error(503, 'Membership service is temporarily unavailable.');
  const memberships = z.array(activeMembershipSchema).safeParse(data ?? []);
  if (!memberships.success) error(503, 'Membership service returned an invalid response.');
  return memberships.data;
}

export function getSelectedMembership(cookies: Pick<Cookies, 'get'>, memberships: ActiveMembership[]) {
  const selectedId = cookies.get(ORGANIZATION_COOKIE);
  return memberships.find((membership) => membership.organization_id === selectedId) ?? null;
}

export function setSelectedOrganization(cookies: Cookies, organizationId: string, secure: boolean) {
  cookies.set(ORGANIZATION_COOKIE, organizationId, {
    path: '/app',
    httpOnly: true,
    sameSite: 'lax',
    secure,
    maxAge: 60 * 60 * 24 * 30
  });
}

export async function requireSelectedMembership(
  locals: App.Locals,
  cookies: Cookies,
  url: URL
): Promise<ActiveMembership> {
  const memberships = await getActiveMemberships(locals);
  if (!memberships.length) error(403, 'Active membership required.');
  const selected = getSelectedMembership(cookies, memberships);
  if (selected) return selected;
  if (memberships.length === 1) {
    setSelectedOrganization(cookies, memberships[0]!.organization_id, url.protocol === 'https:');
    return memberships[0]!;
  }
  redirect(303, '/app/select-organization');
}
