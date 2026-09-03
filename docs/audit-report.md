# BrainSwap MVP senior-engineering and security audit

## Audit date

2026-09-02–03 (America/New_York)

## Recommendation

**`BLOCK PILOT`**

Do not use BrainSwap for real unpublished research data. Focused application, database, and tooling corrections materially improve the repository, but a critical database authorization defect existed in the audited schema. A fresh local reset applied all three migrations and configured both private buckets; SQL lint reported no errors; generated database types were produced; and all 264 adversarial pgTAP assertions passed. The deployed Google OAuth flow previously completed successfully for the exact-email bootstrap administrator, and the bounded CSP/referrer corrections were observed in production. The full authenticated actor matrix, real Storage API behavior, hosted RLS/configuration, deletion and result-edit race recovery, profile-photo policy behavior, access-request email delivery, and remaining browser acceptance checks are still open. Local database evidence and one successful administrator login do not close those boundaries.

This is not a claim that BrainSwap can be made perfectly secure. The recommendation may be reconsidered only after every critical/high finding is corrected, fresh database tests pass, hosted synthetic-data acceptance passes, and the lab approves data handling and provider use.

## Workflow-overhaul addendum

The 2026-09-03 workflow migration simplifies job entry to task summary, prompt, one protected shared-chat link, free-form model preferences, required tools, and an optional deadline. It permits incomplete drafts but retains database-authoritative publication checks; forces one sealed visibility mode; adds profile bio/photo and the fixed profile-model catalog; allows administrators to remove only unclaimed invitations; and permits the latest result author to correct a submitted result in place only until the requester's first workflow response. Legacy exact-task text and exact-URL inline chat context receive explicit compatibility handling. These changes expand the hosted acceptance scope and do not lower the release gate.

## Scope

The review covered the complete tracked repository and current untracked hardening files, including:

- root contributor, setup, security, environment, and package files;
- the full SvelteKit route tree and shared libraries;
- OAuth login/callback/sign-out and access-request paths, server hooks, claims use, protected layouts, and organization selection;
- job, submission, revision, follow-up, profile, notification, and administrator pages/actions;
- file validation and Supabase Storage helpers;
- every Supabase migration, table, constraint, function, policy, grant/revoke, Storage policy, bootstrap script, and pgTAP test;
- application tests, CI workflow, Cloudflare adapter/build output, dependencies, and heuristic security scan; and
- documentation compared with observable implementation.

The audit assumed a hostile authenticated browser capable of directly calling Supabase REST, RPC, and Storage APIs. No real cloud resource was deployed, modified, or asserted to exist.

## Architecture reviewed

- SvelteKit SSR and strict TypeScript
- `@sveltejs/adapter-cloudflare`, Cloudflare Workers Builds configuration, and generated Worker output
- Supabase Google OAuth/PKCE and cookie sessions
- Supabase PostgreSQL and RLS
- public workflow/admin RPCs with internal `private` helpers
- private Supabase Storage bucket and direct authenticated uploads
- Vitest and pgTAP

The architecture is appropriate for a small lab pilot if the database boundary is correct and fully tested. No service-role key, model-provider integration, inference, credential pooling, browser automation, analytics, or canonical research-data subsystem was found.

## Severity summary

| Severity | Initial findings | Current disposition                                                        |
| -------- | ---------------: | -------------------------------------------------------------------------- |
| Critical |                2 | Remediation passed clean local pgTAP; hosted acceptance remains open       |
| High     |                8 | Focused fixes and local database tests passed; hosted verification remains |
| Medium   |                8 | Several application/tooling items corrected; manual verification remains   |
| Low      |                4 | Mostly hardening, maintainability, and documentation corrections           |

Counts group related instances under one root cause. They are not vulnerability-scan totals.

## Critical findings

### C-01: NULL actor checks bypassed privileged RPC authorization

**Initial state:** Several `security definer` functions assigned `private.actor(...)` into a composite record and then used checks such as `if a.id <> expected` or `if a.role <> 'admin'`. For an authenticated uninvited, deactivated, or cross-organization caller, the actor fields were NULL. PostgreSQL comparisons with NULL evaluate to NULL, and a PL/pgSQL `IF` executes only for TRUE, so the rejection branch was skipped.

Affected paths included publish, release, extend, accept, cancel, reopen, administrator invitation, file finalization, and job deletion. A caller still needed a target UUID for many paths, but UUID obscurity is not authorization.

**Required correction:** Every privileged entrypoint must reject `auth.uid() is null` and `a.id is null` explicitly before any comparison, then validate organization and state. Actor checks must use NULL-safe logic.

**Status:** The additive hardening migration replaces the vulnerable entrypoints with explicit missing-actor checks and a stronger actor/claim-owner model. The clean reset and local adversarial pgTAP suite passed, including outsider, deactivated, and cross-organization calls. Hosted hostile-client acceptance remains required.

### C-02: Cross-organization administrator takeover chain

**Initial state:** The NULL behavior in `admin_upsert_membership` allowed an authenticated outsider to supply a victim organization, the attacker's exact email, and `admin`. The failed NULL comparison could fall through and create/reactivate that invitation. The attacker could then call exact-email membership claiming and become an administrator in the victim organization.

**Required correction:** Explicit actor existence/admin checks, same-organization scope, immutable claimed-account ownership, no arbitrary `user_id` binding, and adversarial regression tests for both invitation and subsequent claim.

**Status:** The migration now requires an explicit same-organization administrator, separates invitation from membership updates, and preserves claimed ownership. The clean local pgTAP suite rejected the takeover chain. Hosted Auth and direct-client acceptance remain required.

## High findings

### H-01: RLS helper grants and nullable composite tests could deny legitimate reads

The initial migration revoked access to internal helpers used inside RLS policies. Authenticated policy evaluation could permission-fail rather than return a safe row decision. Elsewhere, tests such as `private.actor(...) is not null` applied to a composite whose nullable attributes could make the whole-row NULL test unreliable. Internal RLS helpers need narrowly sufficient schema/function privileges, and policies should test a non-null identity field explicitly.

The first live pgTAP run also exposed a hardening-integration defect: sensitive-column revokes correctly hid membership, assignment, uploader, and Storage-path fields, but several cross-table RLS policy subqueries still evaluated those hidden columns as the browser role and raised `permission denied` instead of returning rows. Restoring broad table reads would have exposed the protected fields. The correction uses narrow ID-only, boolean-returning `private` security-definer predicates with an explicit EXECUTE allowlist. The later expanded clean suite passed all 264 assertions.

### H-02: Workspace RPC over-returned protected metadata and results

The initial `job_workspace` serialized most of the `jobs` row, including sensitivity notes and internal identifiers, even for members meant to see only a sealed listing. Its single payload decision also exposed all finalized submissions for lab-visible jobs, broader than the result RLS intent. The fix must construct an explicit listing projection and authorize payload, contexts/files, submissions, and revision data separately.

### H-03: Multiple-organization actions could use the wrong membership

Several server actions independently called `my_active_memberships()` and selected the first row instead of the validated organization cookie. An account in multiple organizations could load one organization and mutate another. Shared live-membership selection, error handling, and per-action validation are required; direct RPC scoping remains the final boundary.

### H-04: File lifecycle was incomplete and asymmetric

The initial browser surface did not reach reservation, upload, finalization, download, or deletion helpers. The database had job-file reservation/finalization but no equivalent usable result-file lifecycle, no Storage DELETE policy, incomplete positive extension/MIME enforcement, incomplete ready-only reads, and an incomplete retryable cleanup state. The Storage INSERT policy also did not bind the object metadata reported by Storage to the reservation's exact size and MIME type. A hostile client could reserve a small allowed file and leave a larger or differently typed object that failed later finalization while actual bytes exceeded reservation accounting; stale pending rows could also consume the per-job quota. Finally, job deletion checked only objects joined to file rows, so an untracked object under the job prefix could be orphaned when database metadata was removed.

The hardening migration now compares Storage-inserted size/MIME metadata at INSERT and finalization, includes pending reservations in quota accounting, makes stale cleanup retryable, returns tracked and untracked exact-prefix objects in the deletion manifest, authorizes their deletion only inside the locked deletion workflow, and refuses final database deletion while any exact-prefix object remains. The database-level Storage authorization assertions passed locally. Real browser-to-Storage transfers, metadata behavior, and partial-failure recovery still require hosted acceptance.

### H-05: Administrative lifecycle and last-admin protection were missing

The initial UI claimed the last administrator could not be removed, but no membership update/deactivation workflow or database invariant implemented that claim. Deactivation also needed safe handling of active claims and live sessions. Admin operations must be same-organization, preserve claim ownership, and reject demotion/deactivation of the last usable, bound administrator. The hardening migration uses a membership lock for mutating actors and locks a prior submitter during `request_revision`, serializing revision reassignment and ordinary workflow mutations with administrator deactivation. Sequential authorization behavior passed local pgTAP; true multi-transaction concurrency remains unverified.

### H-06: Cross-organization relational constraints were incomplete

Some context, revision, notification, audit, and parent/follow-up references used single-column foreign keys. Incorrect application/RPC code could associate a row with an object from another organization. Composite `(organization_id, id)` relationships and same-organization checks are required.

### H-07: Database tests did not exercise the authorization boundary

The initial pgTAP file planned only eight structural assertions. It did not create actors or test exact-email claiming, the critical takeover path, RLS behavior, cross-organization isolation, workflow transitions, claim races/expiry, sealed content, Storage, admin scoping, or deletion. A green CI result could therefore coexist with critical vulnerabilities.

### H-08: Draft cancellation bypassed publication and widened visibility

The initial cancellation RPC accepted unpublished drafts. A draft could therefore become `cancelled` without satisfying publication checks, and the cancelled-row listing/workspace paths could expose material that was intended to remain private while draft. Reopen behavior compounded the invalid lifecycle. The hardening migration restores pre-existing unpublished-cancelled rows to `draft`, rejects draft cancellation, rejects reopening an unpublished-cancelled row, and adds state/visibility constraints and adversarial assertions. This migration-time repair must be reviewed on a populated v0.1 clone before it touches operator data.

## Medium findings

### M-01: Return-path validation was too permissive

The initial helper accepted any leading-slash string except `//`/backslash cases. It did not constrain redirects to the protected application or comprehensively reject control/encoded separator cases. The revised helper parses against a fixed sentinel origin and permits only `/app` and descendants; adversarial unit cases were added.

### M-02: CSP configuration was fragile and allowed inline styles

The initial hook emitted a hand-built CSP with `style-src 'unsafe-inline'`; an inline body style also complicated tightening it. CSP moved to SvelteKit's generated mode with explicit Supabase connect origin and `object-src 'none'`. A sequential local production build hydrated the login page without console errors under the generated policy. The deployed policy still needs verification for hosted OAuth and Storage calls.

### M-03: Missing environment variables silently fell back

The server initially fell back to localhost and a build-only placeholder. This could produce a misleading deployment rather than an immediate configuration failure. Current configuration fails clearly when public Supabase values are absent or malformed.

### M-04: Server-side validation and forms were incomplete

Several actions accepted free-form values, malformed UUIDs, unknown tool/capability values, or converted absent fields into the string `"null"`. External URL validation did not consistently reject credentials, malformed authorities, invalid dotted-numeric hosts, bracketed hosts, or an oversized port before its integer cast. Initial job UI omitted deadline, prior context, external links, acceptable models, and files. Submission tools/result files and several lifecycle controls were absent. Current application and SQL validation reject those malformed links without raising a port-overflow error and validate required text with trimmed/nonblank checks while preserving the raw whitespace-significant task, criteria, output-format, and finalized model-response text.

### M-05: Node and dependency policy was not reproducible enough

The manifest used `latest` for most direct dependencies and claimed Node 20+, while locked packages required newer/specific Node lines. Direct dependencies are now exactly pinned, unused direct packages removed, `.nvmrc` selects Node 24.15, and CI uses the same runtime range. On npm versions that support `allowScripts`, reviewed install scripts for the exact locked esbuild, fsevents, sharp, and workerd versions are explicitly allowlisted; dependency updates do not inherit those approvals. Older managed npm versions still rely on the exact lockfile and integrity hashes rather than enforcing that policy.

### M-06: Type generation command initially failed

`npm run db:types` initially redirected into a nonexistent `src/lib/types` directory. The output path was fixed, local generation passed, and `src/lib/types/database.generated.ts` now reflects the reset schema.

### M-07: Dependency advisories exist in development tooling

The final `npm audit` reported three low findings on one `cookie` advisory through SvelteKit and its Cloudflare adapter. An earlier scan also reported four high and one moderate findings through Wrangler/Miniflare; upgrading the pinned Wrangler development tool from 4.86.0 to the reviewed 4.127.1 release moved those transitive dependencies to fixed versions and removed those five findings. `npm audit --omit=dev` reported zero based on manifest classification, but that does not prove bundled framework code is unaffected. npm's remaining suggested fix is a breaking downgrade to SvelteKit 0.0.30, so it was not applied. The application supplies fixed, validated cookie names and attributes; continue monitoring SvelteKit for a compatible dependency fix.

### M-08: Hosted Auth provider scope is an operator-controlled boundary

The application initiates Google OAuth only, but application code cannot prevent sign-in through another Supabase Auth provider that an operator enables. An unintended provider that establishes the invited email could change the identity-proofing assumption even though exact-email membership still blocks uninvited users. The checked-in local configuration disables direct email signup and intentionally does not enable Google; local browser OAuth therefore requires a deliberate temporary Google-provider configuration. Hosted operators must disable anonymous, phone, password/magic-link, manual linking, and unused social providers, and verify those settings with direct negative tests.

## Low findings

### L-01: Heuristic scan covered too few file types

The scanner omitted SQL/TOML/shell and untracked source/config files. It now scans relevant source/config formats for service keys, unsafe Svelte HTML, JWT-like values, private keys, conflict markers, and debug statements while deliberately excluding prose documentation and third-party lock content.

### L-02: CI lacked explicit least privilege and timeouts

CI now declares read-only repository contents permission, bounded job timeouts, and the supported Node version. GitHub Actions references remain tag-based rather than commit-SHA-pinned, a lower-priority supply-chain hardening item.

### L-03: Bootstrap template counted placeholders incorrectly

The template contains four operator values—organization name, slug, admin email, and display name—while its comment referred to three. The comment is corrected, the SQL now aborts if placeholders remain, and the runbook adds an independent pre-execution guard.

### L-04: Dashboard filters were decorative

The initial UI displayed model/effort/status filters without applying them. Those decorative controls were removed so the interface no longer implies unsupported filtering.

## Correctness defects

- Multi-organization mutations could target the first membership rather than the selected membership.
- The organization selector could redirect to itself without a selected membership representation.
- Dashboard joins interacted incorrectly with self-only membership RLS and could lose requester display data.
- Initial job creation omitted intended context, links, deadline, acceptable models, and file workflow.
- Submission input omitted tools and result-file workflow.
- Reopen, follow-up, deletion, mark-read, and several file RPCs had no reachable UI/action despite documentation.
- Profile update was not reliably scoped to the selected organization.
- Notification webhook helper had no reachable call site in the initial implementation.
- Revision/submission history needed stronger uniqueness/state invariants.
- Accepted/cancelled/reopened claim fields and deletion state needed consistency constraints.
- Draft cancellation could bypass publication checks and widen an unpublished row's visibility.

## Deployment defects

- Node requirements in the initial package, CI, and setup guide disagreed with resolved packages.
- Required public Supabase environment variables could silently fall back.
- The checked-in local configuration intentionally remains DB-only unless an operator deliberately enables Google. For local OAuth, Google's authorized redirect URI is the local Supabase Auth provider callback (`http://127.0.0.1:54321/auth/v1/callback`); the application callback (`http://localhost:5173/auth/callback`) belongs in Supabase's redirect allowlist, not Google's.
- The additive migration validates stronger constraints immediately. A populated v0.1 database may contain rows that need operator-reviewed remediation beyond the included deterministic backfills, so a production upgrade requires a dry run and constraint report on a disposable clone before hosted application.
- Generated database types and their output directory were initially missing; local generation now succeeds and the generated file is present.
- The isolated hosted Supabase project received the earlier migrations, bucket configuration, bootstrap data, and Google provider configuration. The new workflow migration and profile-photo bucket still require a reviewed hosted push. Direct hosted hostile-client RLS/Storage checks and complete authenticated browser behavior remain unverified.
- Authenticated browser/OAuth smoke testing and a real Cloudflare deploy-preview test were unavailable without configured Supabase/OAuth services. The final local signed-out production-preview check covered login rendering/hydration, protected-route redirection, response headers, and desktop/mobile widths only.
- The first hosted Workers Builds attempt compiled successfully but stalled when `wrangler deploy` tried to auto-configure SvelteKit through an interactive `sv add` process. The repository now contains a pinned Wrangler dependency, an explicit Worker/assets configuration, an assets ignore list, and a non-mutating deployment dry-run check so hosted deployment does not depend on framework auto-configuration.
- The first hosted login POST exposed an incompatibility between `Referrer-Policy: no-referrer` and SvelteKit's production CSRF origin check: standards-compliant native form navigations sent `Origin: null`, so both Safari and Chrome received a fail-closed 403 before OAuth began. The initial response-header correction left a conflicting document-level `no-referrer` meta policy in place, and browser retesting correctly showed that the defect remained. Both policies now use `same-origin`, which withholds referrers from external sites while preserving a verifiable Origin for same-origin mutations. Regression coverage checks both layers, and the redeployed same-origin form POST proceeded to OAuth while an explicit `Origin: null` probe remained blocked.
- After the referrer correction was deployed, the hosted POST returned a valid 303 but Chrome and Safari appeared to do nothing. The generated CSP limited `form-action` to `'self'`; those browsers can enforce it across redirects and therefore blocked the required navigation from BrainSwap through Supabase Auth to Google. The allowlist now contains only `'self'`, the validated configured Supabase origin, and `https://accounts.google.com`. After redeployment, the invited bootstrap administrator completed the browser OAuth chain and reached the dashboard. Other identities and flows remain unverified.
- Adding an application invitation was initially easy to mistake for sending an email, but it only changed database eligibility. The admin screen now states that behavior directly. A separate Google-verified access-request flow and minimal server-only Resend delivery were added; its cloud secrets, provider retention boundary, delivery, duplicate suppression, and failure behavior remain undeployed/unverified.

## Documentation defects

The original README, security model, implementation plan, acceptance test, and setup guide described file uploads/deletion, follow-ups, deactivation, last-admin protection, adversarial pgTAP coverage, and webhook behavior more confidently than the code supported. They also blurred static inspection, local command execution, and hosted verification. Documentation now labels the release gate, test status, unavailable checks, operation-aware Storage listing denial, and manual cloud responsibilities explicitly.

## Fixes performed

The following corrections are visible in the repository. “Visible” does not mean the database or hosted behavior passed.

### Application/tooling fixes represented in the repository

- restricted OAuth return-path parser plus adversarial unit cases;
- external URL credential/control/malformed-authority validation;
- shared live selected-membership resolution with fail-closed query errors;
- required Supabase environment configuration;
- SvelteKit-generated CSP configuration and removal of the inline body style;
- stronger shared schemas for identifiers, jobs, submissions, profiles, and administrator input;
- preservation of whitespace-significant prompt/model-response text while still rejecting whitespace-only required values;
- complete draft/context/link/model/deadline editing and publish controls;
- partial-draft saving with a separate authoritative publication gate, one sealed workflow, and free-form job model preferences;
- both job/result Storage reservation, direct upload, finalization, download, retry cleanup, and guarded job deletion surfaces;
- upload tables, profile-photo lifecycle, unclaimed-invitation removal, and author-only pre-response result correction;
- revision history, reopen, follow-up, notification mark-read, administrator role/active, and selected-organization profile surfaces;
- metadata-only, post-commit, best-effort webhook calls;
- exact dependency pins and supported Node 24/CI alignment;
- reviewed, version-pinned install-script approvals for supporting npm versions and a Wrangler update that removed the high/moderate development-tool advisories;
- disabled Wrangler usage metrics and dependency instrumentation in the checked-in deployment configuration;
- removed unused direct `jsdom` and redundant direct TypeScript-ESLint packages;
- fixed database-type output directory;
- least-privilege/time-bounded CI;
- broader heuristic source/config scan;
- explicit, non-interactive Cloudflare Workers configuration plus a CI deployment dry run; and
- aligned HTTP and document-level CSRF-compatible `same-origin` referrer policies without cross-site referrer disclosure;
- a bounded OAuth `form-action` allowlist that permits the required Supabase/Google redirect chain;
- optimistic dashboard-tab loading feedback without caching or weakening fresh server authorization;
- versioned, plain-language login copy and a contrast-aware `#e77500` visual accent;
- a Google-verified access-request flow that sends one fixed plain-text sentence through a server-only Resend key, uses a hashed idempotency key, creates no membership, and signs the outsider out; and
- corrected documentation and operator runbook.

### Database fixes represented by the additive migration

- immutable membership claim-owner field and stronger actor predicate;
- validation helpers, malformed numeric/bracket-host and oversized-port rejection, and additional length/state constraints;
- same-organization context, parent, revision, notification, and audit relationships;
- explicit deletion/cleanup state and unpublished-draft cancellation repair;
- replacement of vulnerable RPCs with explicit actor checks;
- membership locking that serializes workflow actions and revision reassignment with deactivation;
- narrow listing/workspace and result projections;
- corrected RLS helper/grant behavior and reduced sensitive-column grants;
- exact job/result Storage reservation, inserted size/MIME binding, pending-quota accounting, and ready/download/delete authorization;
- retryable tracked/untracked exact-prefix Storage cleanup and final orphan check;
- operation-aware Storage SELECT policies that permit authorized object get/info or deletion operations but deny bucket listing; and
- administrator deactivation/claim release and last-usable-bound-admin invariants.
- fixed profile model catalog, profile bio/photo authorization, unclaimed-invitation deletion, and serialized result-edit lock/cleanup recovery.

These database corrections passed a clean local `db:reset`, `db:lint`, and 264-assertion `test:db` run. Hosted configuration and authenticated browser/Storage behavior remain unverified.

## Tests added

- The application test file contains 40 passing Vitest cases. It covers return paths, validation, organization selection, CSP/headers, prompt export, access-request email behavior, pending-tab feedback, simplified forms, status indicators, result-edit/profile UI contracts, atomic draft publication, live upload/editor-state preservation, legacy and follow-up context, and the requested visual tokens.
- `supabase/tests/rls.test.sql` has an explicit `plan(264)` and adversarial actors for anonymous, uninvited, deactivated, cross-organization, requester, claimant, competitor, historical submitter, unrelated member, and administrator cases. It covers exact-email claim/rebinding, RLS/grants, sealed/draft/result visibility, workflow transitions, expiry and competing claims, partial and atomic draft publication, free-form models/tools, legacy-data compatibility, unclaimed-invitation deletion, in-place result correction and requester locking, profile-photo authorization, Storage reservation/metadata/quota/operation authorization, and tracked/untracked cleanup recovery.
- All 264 pgTAP assertions passed on the clean local stack. Sequential outcomes and lock definitions are asserted, but actual two-transaction claim/edit/deactivation concurrency still needs live testing.
- An earlier local `pglast` parse established only that its then-current migration, pgTAP, and bootstrap inputs were syntactically parseable PostgreSQL. That static result did not execute a constraint, policy, function, grant, or assertion; the later clean reset and pgTAP results above are the execution evidence.

## Command results

Application-only checks used Node 24.20.0 (within the required Node 24.15+ release line) and the documented nonfunctional localhost Supabase public values where SvelteKit configuration was required. Running `check` or `test` without those required values failed closed with the intended configuration error. The database rows below report fresh local Supabase execution; no local result implies hosted verification.

| Command/check                                    | Result                       | Evidence/limitation                                                                                                                                                                                                                               |
| ------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm ci` on supported Node 24                    | PASS                         | Clean install from the final lock added 238 packages and reviewed install-script pins left no unreviewed scripts; a sandboxed DNS failure was rerun with explicitly allowed registry access                                                       |
| `npm run format:check`                           | PASS                         | All matched files use Prettier style                                                                                                                                                                                                              |
| `npm run check`                                  | PASS                         | `svelte-check` reported 0 errors and 0 warnings with documented nonfunctional compile-time values                                                                                                                                                 |
| `npm run lint`                                   | PASS                         | ESLint exited 0                                                                                                                                                                                                                                   |
| `npm test`                                       | PASS                         | Vitest reported 1 file and 40 tests passed, including workflow simplification, result correction, profile, access-request email, legacy/follow-up context, atomic publication, live upload/editor-state preservation, and UI contract regressions |
| `npm run security:check`                         | PASS                         | Heuristic scan passed; this is not proof of security                                                                                                                                                                                              |
| `npm run build`                                  | PASS                         | A final sequential Cloudflare-adapter build completed and produced `.svelte-kit/cloudflare`                                                                                                                                                       |
| `npm run deploy:check`                           | PASS                         | Wrangler 4.127.1 parsed the explicit Worker/assets configuration and completed a non-mutating upload dry run without auto-configuration; esbuild emitted one non-fatal tree-shaking warning for a side-effect-free Supabase SSR import            |
| `wrangler telemetry status`                      | PASS                         | Reported `Disabled (set by wrangler config)`                                                                                                                                                                                                      |
| `npm run db:types`                               | PASS                         | Generated `src/lib/types/database.generated.ts` from the clean local schema                                                                                                                                                                       |
| `npm run db:start`                               | PASS                         | Docker-backed local Supabase started successfully; Studio was available at `http://127.0.0.1:54323`                                                                                                                                               |
| `npm run db:reset`                               | PASS                         | Applied `202609030001_initial.sql`, `202609030002_security_hardening.sql`, and `202609030003_workflow_overhaul.sql`; both private buckets were configured                                                                                         |
| `npm run db:lint`                                | PASS                         | Supabase database lint reported no errors                                                                                                                                                                                                         |
| `npm run test:db`                                | PASS                         | pgTAP reported `Files=1, Tests=264, Result=PASS` after the workflow, atomic-publication, edit-lock, photo, migration-compatibility, and cleanup-race additions                                                                                    |
| `pglast` static SQL parse                        | PASS (EARLIER SNAPSHOT ONLY) | An earlier revision parsed successfully; subsequent final database reset, lint, and pgTAP execution are the authoritative SQL evidence                                                                                                            |
| pgTAP plan/count consistency                     | PASS                         | Executed `plan(264)` completed 264 assertions                                                                                                                                                                                                     |
| `npm audit`                                      | COMPLETED                    | 3 low findings remain on one SvelteKit `cookie` advisory after the Wrangler update removed the earlier 4 high and 1 moderate findings; see M-07                                                                                                   |
| `npm audit --omit=dev`                           | PASS BY NPM SCOPE            | npm reported 0 vulnerabilities after omitting declared development dependencies; see M-07's bundling caveat                                                                                                                                       |
| Signed-out local browser/header smoke            | PASS, LIMITED                | Login hydrated with no console errors at 1280x800 and 390x844; mobile had no horizontal overflow; `/app` returned 303 to `/login?next=%2Fapp`                                                                                                     |
| Local sensitive-page headers                     | PASS, LIMITED                | Login had generated CSP, `no-store, private`, nosniff, `same-origin` referrer policy, Permissions Policy, and frame denial; HSTS and final Cloudflare behavior need HTTPS retest                                                                  |
| Local login form CSRF smoke                      | PASS, LIMITED                | Rendered HTTP and document policies were both `same-origin`; the form POST reached a local PKCE 303, while an explicit `Origin: null` request remained blocked with 403                                                                           |
| Local access-request form smoke                  | PASS, LIMITED                | With fake server-only email settings, the rendered page showed the button without exposing those values; its POST produced Google PKCE S256, preserved the request intent, and reduced an external `next` to `/app`; no email was sent            |
| `git diff --check`                               | PASS                         | Final diff has no whitespace errors                                                                                                                                                                                                               |
| Hosted OAuth/Storage/authenticated browser tests | PARTIAL                      | The invited bootstrap administrator completed Google OAuth and reached the dashboard after the CSP/referrer fixes; other actors, sign-out, Storage, and complete workflows remain open                                                            |

## Residual risks

- The critical SQL fix passed the clean local adversarial database suite; hosted project configuration and direct authenticated-client behavior are not yet proven.
- The hardening migration may reject constraint-invalid rows in a populated v0.1 database; its deterministic backfills are not a substitute for a reviewed clone dry run and operator-approved data remediation.
- Files are allowlisted but not malware-scanned or content-inspected.
- The migration's operation-aware Storage SELECT policy is designed to deny bucket listing while permitting authorized exact-object get/info and deletion operations. The hosted Storage schema/version and helper behavior are unverified; path secrecy is not a control.
- Administrators necessarily have broad organization content access.
- Compromised Auth, administrator, helper, Supabase, Cloudflare, Resend, webhook, or AI-provider accounts remain risks.
- Hosted Auth-provider settings can drift and are not enforceable by the application repository.
- Manual provider use and retention/training policies are outside BrainSwap.
- User classification/authorization mistakes can disclose material to otherwise authorized lab members/helpers.
- Hosted configuration may drift from migrations and checked-in config.
- Claim/deactivation locking, operation-aware Storage checks, exact-prefix deletion recovery, and webhook partial-failure behavior require live testing.
- Access-request delivery necessarily gives Resend the operator and requester email addresses. Its 24-hour per-address idempotency window does not stop abuse spread across many Google accounts, and the new hosted path has not yet been tested.
- Signed-out local CSP, caching headers, and responsive login layout passed a limited smoke test. Hosted invited-admin OAuth later passed, but the remaining authenticated layout, actor, keyboard, external-link, sign-out, and Storage cases remain unverified.
- Backup, retention, data residency, incident response, and institutional approval are not encoded by the repository.

## Items requiring manual cloud verification

An isolated Supabase project received the earlier migrations, bucket configuration, bootstrap data, and Google-provider configuration on 2026-09-03. The workflow migration and profile-photo bucket have not yet been pushed there. Those setup actions do not replace the hostile-client and browser acceptance evidence below; the items remain open until their behavior is tested and recorded.

1. Create an isolated Supabase project. Apply the migrations to a clean database, then dry-run the v0.1-to-hardened upgrade against a disposable copy of any populated v0.1 data; inventory and explicitly remediate every constraint-invalid row before a hosted upgrade.
2. Seed/inspect `job-files` and `profile-photos` privacy, size/MIME limits, reservation metadata binding, pending-quota accounting, operation-aware list denial, and the Storage operation helper/version precondition.
3. Inspect RLS and grants for every table/function on the hosted project.
4. Bootstrap a synthetic organization/admin with no placeholders and verify idempotency.
5. Configure Google consent/test users and use the Supabase Auth provider callback shown by Supabase as Google's authorized redirect URI. For local testing that is `http://127.0.0.1:54321/auth/v1/callback`; keep `http://localhost:5173/auth/callback` in Supabase's application redirect allowlist only. Disable every Auth provider and identity-linking path outside the approved Google flow.
6. Maintain the Cloudflare Worker through Workers Builds with `npm run build`, `npx wrangler deploy`, root path `/`, Node 24.15+, the public Supabase values, and only reviewed server-side integrations. Add public values as both build variables and Worker runtime text variables.
7. Test invited/uninvited/deactivated/multi-org login, sign-out, and open-redirect cases.
8. Execute the full actor matrix and direct hostile RPC/REST/Storage calls, including real concurrent claim and deactivation/revision-reassignment transactions.
9. Exercise both job/result file lifecycles, verify bucket listing is denied, attempt mismatched size/MIME uploads, force tracked and untracked exact-prefix cleanup retries, and test expiry/deactivation.
10. Verify deployed CSP/security/cache headers and desktop/mobile/keyboard workflows.
11. Create a restricted Resend sending key, configure the three server-only access-request variables, and verify exact body, Google-derived address, sign-out, no membership creation, duplicate suppression, delivery failure, and absence from application logs/client code.
12. Inspect actual Cloudflare/Supabase/webhook logs for payload leakage and the intentionally narrow Resend transactional record for unexpected content.
13. Configure and approve backups, retention/deletion, monitoring, incident contacts, provider policy, and the lab data boundary.

## Final pilot gate

The application is **not approved for a pilot under this audit**. The repository is ready for an isolated synthetic-data hosted deployment used solely to complete OAuth, authenticated browser, Storage, RLS/configuration, and deployed-header verification. Anything involving real unpublished research should remain blocked until the recommendation is formally changed after evidence-backed retesting.
