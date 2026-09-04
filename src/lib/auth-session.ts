// Browsers cap persistent cookies at roughly 400 days. Successful token
// refreshes renew this lifetime, so an active user remains signed in until
// explicit sign-out unless the identity provider revokes the session.
export const AUTH_COOKIE_MAX_AGE_SECONDS = 400 * 24 * 60 * 60;

export function authCookieOptions(secure: boolean) {
  return {
    path: '/',
    sameSite: 'lax' as const,
    secure,
    maxAge: AUTH_COOKIE_MAX_AGE_SECONDS
  };
}
