import { createServerClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import type { Handle } from '@sveltejs/kit';
export const handle: Handle = async ({ event, resolve }) => {
  const supabaseUrl = env.PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
  const publishableKey = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'build-only-placeholder';
  event.locals.supabase = createServerClient(supabaseUrl, publishableKey, {
    cookies: {
      getAll: () => event.cookies.getAll(),
      setAll: (items) =>
        items.forEach(({ name, value, options }) => event.cookies.set(name, value, { ...options, path: '/' }))
    }
  });
  event.locals.safeGetClaims = async () => {
    const { data, error } = await event.locals.supabase.auth.getClaims();
    const sub = data?.claims?.sub;
    return error || typeof sub !== 'string' ? null : sub;
  };
  event.locals.userId = await event.locals.safeGetClaims();
  const response = await resolve(event, {
    filterSerializedResponseHeaders: (n) => n === 'content-range' || n === 'x-supabase-api-version'
  });
  const origin = new URL(supabaseUrl).origin;
  response.headers.set(
    'Content-Security-Policy',
    `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' ${origin}; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`
  );
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'no-referrer');
  response.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  response.headers.set('X-Frame-Options', 'DENY');
  if (event.url.pathname.startsWith('/app') || event.url.pathname.startsWith('/auth'))
    response.headers.set('Cache-Control', 'no-store, private');
  return response;
};
