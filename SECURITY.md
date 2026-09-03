# Security model

This document describes the intended boundary and what is visible in the repository. It is not a certification. The current audit recommendation is `BLOCK PILOT`; see [docs/audit-report.md](docs/audit-report.md).

## Identity and membership

Google OAuth is brokered by Supabase using a PKCE code exchange and cookie-based SSR session. Protected application code derives the user identifier from `getClaims()` and treats Auth failures as signed out. The OAuth return path is restricted to `/app` and descendants.

Auth identity alone grants no application access. Membership claiming is intended to read the confirmed email from `auth.users`, normalize it, and bind only an exact active invitation. Authorization must require both the current `user_id` and immutable claim ownership, so an administrator cannot rebind a claimed invitation to another account. Institutional-domain membership is not inferred.

BrainSwap initiates Google OAuth only. Operators must keep anonymous sign-in, manual identity linking, direct email/password or magic-link account creation, phone auth, and unused social providers disabled. New Google Auth identities may still be created, but they receive no application data unless an active exact-email membership is successfully claimed.

Every protected operation must re-query current active memberships. The selected-organization cookie is only a hint; server actions and database RPCs must validate it. Deactivation therefore takes effect on the next protected request even if the Auth session remains valid.

## Database boundary

RLS is enabled on exposed application tables and direct workflow writes are revoked from ordinary clients. Workflow and administrative changes use narrow RPCs that derive `auth.uid()` and the current membership. Security-definer code must use `search_path = ''`, schema-qualified references, NULL-safe actor checks, explicit state validation, and minimal EXECUTE grants.

Internal helpers live in the non-exposed `private` schema. They still need the limited USAGE/EXECUTE privileges required when an authenticated query evaluates an RLS policy. Removing those helper privileges can make legitimate policy evaluation fail; it does not strengthen the boundary.

The initial audit found a critical SQL three-valued-logic flaw: several privileged functions compared fields of a possibly NULL actor with `<>`, allowing the `IF` check to fall through. One path could create an administrator invitation in another organization. The additive hardening migration replaces these checks. On 2026-09-03, a clean local reset applied both migrations, SQL lint reported no errors, and all 207 adversarial pgTAP assertions passed. Hosted policy/configuration and authenticated browser verification remain required before a pilot.

## Content visibility

Job title and listing summary are lab-visible after publication. Drafts are limited to requester/admin. Protected task payload, sensitivity notes, context, file metadata, submissions, and revision instructions must not be returned merely because a member can see the listing.

For `claimed_only` jobs, protected material is limited to:

- the requester;
- an active organization administrator;
- the current claimant while the claim is unexpired; and
- an active member who authored a finalized submission, only where historical access is intentionally supported.

Claim checks use database time and row locking. Expired claimants must lose claimant-only payload and Storage access immediately. Dashboard rows and notifications contain safe metadata only; no task excerpts, model output, or revision text should be copied into them.

## Files and Storage

`job-files` is configured as a private bucket with a 25 MiB object limit. The application-level reservation limit is 100 MiB per job, including pending reservations. Supported formats are PDF, plain text/Markdown/CSV/JSON, PNG/JPEG/WebP, and non-macro Office Open XML. HTML, SVG, scripts, executables, generic binary uploads, and macro-enabled Office files are outside the allowlist.

New reserved object paths contain organization/job UUIDs plus a random UUID; the original filename is retained only in protected database metadata. A path is not authorization. Storage INSERT/SELECT/DELETE policies and the associated database reservation must all agree. Uploads must use the exact reserved path with `upsert: false`; finalization verifies the stored size and MIME metadata before marking a file ready.

The hardening migration makes Storage SELECT authorization operation-aware: exact-object download/info operations may read a downloadable object, delete operations may select an object that the caller may delete, and bucket-list operations are denied. This depends on the documented Supabase Storage operation helper and must be verified against the deployed Storage version. The application must not rely on path secrecy. Downloads use the Storage API and browser attachment behavior. Deletion must use the Storage API, be retryable, and remove database metadata only after object cleanup succeeds; normal application SQL must not directly delete `storage.objects` rows.

An upgrade from the original migration may retain already-created object paths that include a sanitized original filename. The additive hardening migration does not rename Storage objects. Before admitting real data, operators must inspect any preexisting objects and either complete and verify a Storage-API migration or recreate the pilot project from clean migrations.

The hardening migration also validates stricter row constraints and may fail closed on populated v0.1 data that no longer satisfies them. Any nonempty upgrade requires a backup, a dry run against a disposable restored copy, explicit data remediation, and a second verified migration attempt; “additive” does not mean automatically compatible with every legacy row.

Extension/MIME matching is not malware scanning. Uploaded content remains untrusted and must not be rendered as active content.

## Browser, network, and logging boundaries

User/model text is rendered as text. User-provided external links are accepted only as HTTPS URLs without embedded credentials. BrainSwap never previews or server-fetches those links. External anchors use opener/referrer protections. Plain HTTP is limited to the deliberately configured local Supabase endpoint during development; it is not accepted for user-provided links.

SvelteKit origin checks remain enabled. Security headers include a SvelteKit-generated CSP, `frame-ancestors 'none'`, `object-src 'none'`, nosniff, `Referrer-Policy: same-origin`, a matching document-level referrer policy, a restrictive Permissions Policy, frame denial, and `no-store` for authenticated/authentication responses. `same-origin` sends no referrer to external sites while preserving the real `Origin` on native same-origin form POSTs so SvelteKit can enforce its production CSRF check. CSP form navigation is restricted to the application, the configured Supabase origin, and `https://accounts.google.com`, which are the required OAuth redirect-chain origins. These controls still require hosted OAuth verification after deployment.

Logs and audit metadata must exclude prompts, responses, revision instructions, credentials, tokens, OAuth codes, sensitive URLs, filenames, and file contents. There is no analytics/tracking subsystem. Any optional webhook is server-only, metadata-only, and best effort after the core transaction; hosted endpoint ownership and behavior require manual verification.

## Governance and residual risk

Organization administrators can inspect organization content. Compromised Google, Supabase, Cloudflare, administrator, helper, or AI-provider accounts remain material risks. BrainSwap does not virus-scan files, control a helper's manual provider use, guarantee provider deletion, or validate scientific correctness. Operators must define retention, backups, incident contacts, approved providers, collaborator permissions, and institutional data classification before a pilot.

Report suspected access or file exposure to the lab operator. The operator should deactivate affected memberships, preserve only safe audit evidence, rotate implicated credentials, and follow institutional incident policy. Do not describe BrainSwap as absolutely secure.
