# Threat model and review

## Assets and adversaries

Assets are invitations, task payloads, research context, output, files, and operational audit records. Threats include anonymous/uninvited users, inactive or unrelated members, cross-organization insiders, expired claimants, malicious uploaders, compromised browsers, and accidental operator misconfiguration. Supabase, Cloudflare, Google, selected AI providers, and approved institutional storage are external trust boundaries.

## Controls reviewed

- Exact confirmed-email claim; live membership and organization revalidation; no domain authorization.
- RLS on every exposed table, reduced grants, qualified security-definer SQL, row-locked claims.
- Sealed visibility includes expiry and finalized historical participation, not UUID secrecy.
- POST mutations, safe relative returns, plain-text rendering, no server URL fetching or previews.
- Private exact-path Storage policies, allowlists/limits, API deletion before guarded DB cascade.
- Metadata-only audit/notification records; CSP/no-store/no-referrer and no analytics.
- No model-provider credentials, automation, inference, quota pooling, or session handling.

## Residual risks / verification debt

Files are not virus-scanned; MIME and extension can lie. Manual helper behavior and provider retention are outside BrainSwap. Admins can inspect content. A compromised authenticated account can exercise its member rights. Local pgTAP cannot prove hosted configuration until migrations and bucket seeding are verified there. Cloud provider settings, Google test users, redirects, backups, retention, incident contacts, desktop/mobile visual behavior, and institutional data approval remain operator responsibilities.
