import { createBrowserClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import { authCookieOptions } from '$lib/auth-session';

let client: ReturnType<typeof createBrowserClient> | undefined;

export function getBrowserSupabase() {
  if (!env.PUBLIC_SUPABASE_URL || !env.PUBLIC_SUPABASE_PUBLISHABLE_KEY)
    throw new Error('Supabase public configuration is missing.');
  client ??= createBrowserClient(env.PUBLIC_SUPABASE_URL, env.PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    },
    cookieOptions: authCookieOptions(typeof window !== 'undefined' && window.location.protocol === 'https:')
  });
  return client;
}
