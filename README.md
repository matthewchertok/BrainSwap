# BrainSwap

**Hand off AI jobs when your model cannot finish them.** BrainSwap is an invite-only, organization-scoped coordination application for a small research lab. A requester packages a task; another authorized member manually uses an AI service they control and returns an immutable result. BrainSwap performs no inference and accepts no provider credentials.

## Architecture

SvelteKit renders on the server and deploys through the Cloudflare adapter. Supabase provides Google/PKCE Auth, PostgreSQL, and one private Storage bucket. `hooks.server.ts` refreshes cookie sessions and checks verified claims; protected layouts validate an active membership on every request. SQL RPCs implement state transitions, while RLS and reduced grants remain the final authorization boundary. Direct browser Storage uploads use server-reserved random paths.

## Layout

- `src/routes` — login/callback, protected dashboard, job workspace, profile/admin/notifications
- `src/lib` — branding, validation, exports, display and authorization helpers
- `supabase/migrations` — schema, constraints, RLS, Storage policies, atomic RPCs
- `supabase/tests` — transactional pgTAP checks
- `docs` — plan, threat model, pilot acceptance procedure
- `MANUAL_SETUP.md` — local and cloud operator runbook

## Local start

Copy `.env.example` to `.env`, install with `npm ci`, start Docker, run `npm run db:start && npm run db:reset`, then use the local Supabase values in `.env` and run `npm run dev`. Replace bootstrap placeholders before running `supabase/bootstrap-admin.sql`. See `MANUAL_SETUP.md`.

## Commands

`npm run check`, `npm run lint`, `npm test`, `npm run build`, `npm run security:check`, `npm run db:lint`, and `npm run test:db` cover application and database checks. `npm run db:types` regenerates database types.

## Data/provider boundaries

Do not use BrainSwap for Restricted or Highly Restricted information, PHI, unnecessary PII, restricted human-subject/export-controlled records, credentials, or unauthorized material. Uploaded indicators are allowlisted but files are not malware-scanned. Prefer approved institutional storage for large, sensitive, collaborator-provided, or long-lived material. A lab must approve its data-use boundary before real research enters a pilot. See `SECURITY.md`.
