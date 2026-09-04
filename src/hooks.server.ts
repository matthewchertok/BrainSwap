import { createServerClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import { authCookieOptions } from '$lib/auth-session';
import { applyBaselineSecurityHeaders } from '$lib/server/security-headers';
import type { Handle } from '@sveltejs/kit';
export const handle: Handle = async ({ event, resolve }) => {
  const supabaseUrl = env.PUBLIC_SUPABASE_URL;
  const publishableKey = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!supabaseUrl || !publishableKey)
    throw new Error('PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required.');
  const parsedSupabaseUrl = new URL(supabaseUrl);
  const localSupabase = ['localhost', '127.0.0.1', '[::1]'].includes(parsedSupabaseUrl.hostname);
  if (parsedSupabaseUrl.protocol !== 'https:' && !(parsedSupabaseUrl.protocol === 'http:' && localSupabase))
    throw new Error('PUBLIC_SUPABASE_URL must use HTTPS, except for localhost development.');
  event.locals.supabase = createServerClient(supabaseUrl, publishableKey, {
    cookieOptions: authCookieOptions(event.url.protocol === 'https:'),
    cookies: {
      getAll: () => event.cookies.getAll(),
      setAll: (items) =>
        items.forEach(({ name, value, options }) => event.cookies.set(name, value, { ...options, path: '/' }))
    }
  });
  event.locals.safeGetClaims = async () => {
    try {
      const { data, error } = await event.locals.supabase.auth.getClaims();
      const sub = data?.claims?.sub;
      return error || typeof sub !== 'string' ? null : sub;
    } catch {
      return null;
    }
  };
  event.locals.userId = await event.locals.safeGetClaims();
  const response = await resolve(event, {
    filterSerializedResponseHeaders: (n) => n === 'content-range' || n === 'x-supabase-api-version'
  });
  applyBaselineSecurityHeaders(response.headers);
  if (
    event.url.pathname.startsWith('/app') ||
    event.url.pathname.startsWith('/auth') ||
    event.url.pathname === '/login' ||
    event.url.pathname === '/unauthorized'
  )
    response.headers.set('Cache-Control', 'no-store, private');
  if (event.url.protocol === 'https:' && !['localhost', '127.0.0.1', '[::1]'].includes(event.url.hostname))
    response.headers.set('Strict-Transport-Security', 'max-age=31536000');
  return response;
};
