import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { loadEnv } from 'vite';

const environment = loadEnv(process.env.NODE_ENV ?? 'development', process.cwd(), '');
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL ?? environment.PUBLIC_SUPABASE_URL;
const publishableKey = process.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? environment.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const googleOAuthOrigin = 'https://accounts.google.com';

if (!supabaseUrl || !publishableKey) {
  throw new Error('PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required.');
}

let supabaseOrigin;
try {
  const parsed = new URL(supabaseUrl);
  const localHttp = parsed.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  if (parsed.protocol !== 'https:' && !localHttp) throw new Error('unsupported protocol');
  supabaseOrigin = parsed.origin;
} catch {
  throw new Error('PUBLIC_SUPABASE_URL must use HTTPS, except for an HTTP localhost development URL.');
}

export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    csp: {
      mode: 'auto',
      directives: {
        'default-src': ['self'],
        'script-src': ['self'],
        'style-src': ['self'],
        'img-src': ['self', 'data:', 'blob:'],
        'connect-src': ['self', supabaseOrigin],
        'frame-ancestors': ['none'],
        'base-uri': ['self'],
        // Chromium and WebKit can apply form-action to every hop of a form
        // redirect chain. OAuth starts with a same-origin POST, then redirects
        // through Supabase Auth to Google's account chooser.
        'form-action': ['self', supabaseOrigin, googleOAuthOrigin],
        'object-src': ['none']
      }
    }
  }
};
