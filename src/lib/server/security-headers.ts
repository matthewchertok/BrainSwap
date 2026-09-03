export function applyBaselineSecurityHeaders(headers: Headers): void {
  headers.set('X-Content-Type-Options', 'nosniff');
  // `no-referrer` also forces Origin: null for native form navigations, which
  // makes SvelteKit's production CSRF origin check reject legitimate forms.
  // `same-origin` preserves that check and still sends no referrer off-site.
  headers.set('Referrer-Policy', 'same-origin');
  headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  headers.set('X-Frame-Options', 'DENY');
}
