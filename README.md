# BrainSwap

BrainSwap is a private, invitation-only task-handoff application for a small research lab. A requester packages the next step of a task, an authorized member manually uses an AI service they control, and the requester reviews the returned result. BrainSwap does not run model inference, accept model-provider credentials, automate consumer model websites, scrape conversations, or pool quotas.

## Review status

**Current recommendation: `BLOCK PILOT`.** The local pass completed formatting, Svelte/type checks, lint, unit tests, the heuristic scan, the Cloudflare production build, a fresh database reset, SQL lint, and database-type generation; all 207 pgTAP assertions passed. The reset applied both migrations and updated the private `job-files` bucket. Hosted Google OAuth has completed successfully for the invited bootstrap administrator, but the full authenticated actor matrix, real Storage API behavior, hosted RLS/configuration, and remaining browser acceptance items are still open. Do not use real unpublished research data until the blocking items in [the audit report](docs/audit-report.md) are closed.

## Architecture

- SvelteKit SSR with strict TypeScript and `@sveltejs/adapter-cloudflare`
- Cloudflare Workers deployment through Workers Builds, with the generated worker in `.svelte-kit/cloudflare`
- Supabase Google/PKCE Auth with cookie-based SSR sessions
- Supabase PostgreSQL with RLS as the final authorization boundary
- Narrow PostgreSQL RPCs for workflow and administrative mutations
- One private Supabase Storage bucket, `job-files`
- Server-only Resend delivery for verified Google-account access requests
- Vitest for application tests and pgTAP for database authorization tests

Server requests use the caller's Supabase cookie session and publishable key. No service-role key is required by the application. Organization selection is an HTTP-only convenience cookie that must be matched to a current active membership on every protected operation.

Adding an exact-email invitation in the admin screen changes eligibility but does not send an invitation email. An uninvited person may instead choose **Request access**, verify their address through Google, and have BrainSwap send that one address to the configured operator. The operator still decides whether to add an invitation; the request never creates a membership.

## Repository layout

- `src/routes` — authentication, protected application pages, jobs, profile, notifications, and administration
- `src/lib` — validation, prompt/export helpers, Storage helpers, server membership selection, and the destination for database types generated from a live schema
- `supabase/migrations` — schema, RLS, Storage policies, and RPCs
- `supabase/tests` — pgTAP authorization and workflow tests
- `supabase/bootstrap-admin.sql` — operator-reviewed initial organization/admin/model bootstrap
- `docs` — implementation status, threat model, acceptance test, and audit report
- `MANUAL_SETUP.md` — ten-step local and hosted setup runbook

## Local verification

Use Node.js 24.15 or later in the Node 24 release line. If `nvm` is installed, `.nvmrc` selects the audited version; otherwise select a compatible Node 24 release with your version manager. Then run:

```sh
nvm use # omit when using a different version manager
cp .env.example .env # untracked, nonfunctional compile-time placeholders only
npm ci
npm run format:check
npm run check
npm run lint
npm test
npm run security:check
npm run build
npm run deploy:check
```

The example values are sufficient only for static application checks and a production build; they cannot authenticate or contact Supabase. Replace them with the local values reported by `supabase status` before starting the application. Never commit `.env`.

Database commands additionally require Docker and the local Supabase CLI stack:

```sh
npm run db:start
npm run db:reset
npm run db:lint
npm run test:db
npm run db:types
```

See [MANUAL_SETUP.md](MANUAL_SETUP.md) before attempting local OAuth or any hosted setup. Passing local application/database checks does not substitute for hosted authentication, Storage, or authenticated browser acceptance testing.

## Data boundary

Do not enter Restricted or Highly Restricted information, PHI, unnecessary PII, credentials, restricted human-subject or export-controlled records, personnel/student records, or material the lab is not authorized to disclose. Files are allowlisted by declared extension and MIME type but are not malware-scanned or content-inspected. BrainSwap is coordination software, not a canonical research-data repository. The lab must approve its data-use, retention, backup, incident-response, and AI-provider boundaries before any real pilot.
