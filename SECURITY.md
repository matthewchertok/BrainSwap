# Security model

## Identity and authorization

Google OAuth is brokered by Supabase with PKCE and cookie sessions. Server protection uses verified `getClaims()` output, never an unverified session. Auth identity alone grants nothing: `claim_available_memberships()` reads a confirmed email from `auth.users` and atomically links only exact normalized invitations. Every protected request checks live active membership; the organization cookie is only a validated selection hint.

All data carries an organization boundary and actor relationships use membership IDs. Exposed tables have RLS and workflow writes are revoked in favor of narrow RPCs. Privileged helpers live in `private`, use `search_path = ''`, qualify objects, derive `auth.uid()`, and return narrowly scoped results. Administrators receive invitation/audit views through explicit RPCs, not broad member-table access.

## Content and claims

Drafts belong to requester/admin. Lab-visible payloads are readable by active members. Sealed payload/context/files are limited to requester, admin, an unexpired current claimant, and authors of finalized prior submissions. Claim checks use database time and row locking; expiry requires no cron and immediately removes claimant-only access. Results and revision requests are preserved rather than overwritten. Accepted work is terminal.

## Files

`job-files` is private, capped at 25 MiB/object, with a 100 MiB/job reservation limit. Supported formats are PDF, text/Markdown/CSV/JSON, PNG/JPEG/WebP, and non-macro Office Open XML. Files are untrusted and **not malware-scanned**. Exact reserved random paths gate authenticated upload; authorized exact-object downloads follow payload rules. The app never previews HTML/SVG and never treats names or UUIDs as authority. Deletion removes objects through the Storage API before database deletion; the RPC refuses deletion while matching Storage objects exist.

## Browser and integration boundaries

User text is rendered as plain text; links are HTTPS (localhost HTTP only in development), are never server-fetched, and open with no opener/referrer. Mutations are POST, retaining SvelteKit origin protections. Protected/auth responses are `no-store`; CSP, frame denial, nosniff, referrer and Permissions Policy headers are applied. Webhook URLs remain server-only and messages must contain metadata only; failures are nonfatal.

BrainSwap never requests, stores, pools, or operates model credentials/cookies/keys, never automates a consumer model UI, and never performs inference. Helpers manually use provider accounts under their own authorization and retention settings.

## Governance, reporting, and residual risk

This MVP is coordination software, not a canonical repository and is not approved for Restricted/Highly Restricted information. Organization administrators can access content for administration. Report suspected access, invitation, or file exposure immediately to the lab operator; the operator should deactivate affected memberships, preserve safe audit metadata, rotate Supabase/Cloudflare credentials if implicated, and follow institutional incident policy.

Residual risks include malicious uploads without antivirus/content inspection; provider-link sharing behavior; compromised OAuth/provider accounts; administrators' necessary content access; webhook endpoint trust; user mistakes in classification; and no external security audit. Browser visual/accessibility testing and hosted RLS configuration must be completed before pilot approval. Do not describe this system as perfectly secure.
