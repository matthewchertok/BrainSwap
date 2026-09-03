# BrainSwap contributor guide

## Current gate

The repository is under pre-deployment security review. The current recommendation is `BLOCK PILOT`; real unpublished research data is prohibited until the database test suite passes from a clean stack and the hosted acceptance items in `docs/audit-report.md` are closed. Never describe a static inspection or an unexecuted test as a passed control.

## Architecture

- SvelteKit SSR on Cloudflare Workers, deployed through Workers Builds; TypeScript is strict and shared validation belongs in `src/lib`.
- Supabase Auth, PostgreSQL, and private Storage are the only backend. Server requests use the caller's cookie session and publishable key, never a service-role key.
- PostgreSQL RLS is the final authorization boundary. Browser users are hostile clients and may call REST, Storage, and RPC APIs directly.
- Organization selection is an HTTP-only convenience cookie. Every protected load or mutation must resolve it against current active memberships and fail closed on membership-query errors.
- Privileged public RPC entrypoints may use `security definer`; internal authorization helpers belong in `private`. Every definer uses `search_path = ''`, schema-qualified object names, explicit NULL-safe authorization checks, and the narrowest workable grants. RLS helpers must retain the schema/function privileges required for policy evaluation; do not confuse revoking direct mutation entrypoints with making policy helpers uncallable.

## Security invariants

- Eligibility is an exact normalized invitation email confirmed by Supabase Auth. A session or institutional email domain alone is never authorization.
- Never trust browser-supplied actor, membership, organization, role, or model identifiers. Re-derive the actor and selected organization server-side and again at the database boundary.
- Never log or notify task bodies, model output, revision instructions, credentials, tokens, OAuth codes, sensitive URLs, filenames, or file contents.
- Never integrate with model providers, accept their credentials, automate their websites, scrape conversations, or pool quotas. Helpers perform model work manually.
- Sealed content is limited to the requester, an organization administrator, the current unexpired claimant, and explicitly intended finalized submission authors.
- Uploaded objects remain private. Paths are server-reserved and randomized; reservations and ready state are authorized at the database boundary; uploads use `upsert: false`; limits are 25 MiB/file and 100 MiB/job.
- Treat file extension and MIME checks as allowlisting, not malware detection. Do not render uploaded HTML/SVG or server-fetch user URLs.
- Render user and model text as text; never use `{@html}` or unsanitized Markdown. Mutations use POST and retain SvelteKit origin checks.
- Storage SELECT authorization is operation-aware: exact-object download/info and authorized deletion are allowed, while bucket-list operations are denied. The deployed Supabase Storage schema/version must provide the checked operation helper; object names are never authority.

## Toolchain and checks

Use Node.js `>=24.15.0 <25` (`.nvmrc` is authoritative) and install with `npm ci`. Run:

`npm run format:check`, `npm run check`, `npm run lint`, `npm test`, `npm run security:check`, `npm run build`, `npm run db:lint`, and `npm run test:db`.

Database authorization changes require a fresh local reset and pgTAP run. If Docker, OAuth credentials, or hosted services are unavailable, report the check as not run rather than inferring success.

## Non-goals

No public membership enrollment/community, billing, chat, analytics, model inference/API integration, credential or quota sharing, browser automation, or canonical research-data storage. Google may create an Auth identity on first OAuth sign-in, but only an active exact-email invitation can create application membership.
