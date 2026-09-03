# Threat model

Status date: 2026-09-03 (America/New_York)

## Scope and security objective

BrainSwap coordinates manual AI task handoffs inside one or more private research-lab organizations. The primary objective is to prevent anyone outside the intended principals from reading, mutating, administering, or inferring organization data, especially sealed task content and files. Scientific correctness and AI-provider behavior are outside the software boundary.

## Assets

- invitation email addresses, membership bindings, roles, and active status;
- lab-visible job listings;
- protected task payloads, sensitivity notes, context, external links, and prompts;
- model responses, revision instructions, submission history, and follow-up snapshots;
- uploaded job/result files and Storage object paths;
- notification and audit metadata;
- Supabase Auth cookies/tokens, OAuth codes, provider configuration, and deployment secrets.

## Actors and adversaries

- anonymous visitor;
- authenticated but uninvited account;
- deactivated former member with a live Auth session;
- active member of another organization;
- unrelated active member in the same organization;
- requester;
- current unexpired claimant;
- expired or losing competing claimant;
- historical finalized-submission author;
- organization administrator;
- malicious uploader or compromised authorized account;
- misconfigured operator or compromised cloud/provider account.

## Trust boundaries

The browser is hostile. Supabase Auth establishes identity, while PostgreSQL/RLS and narrowly granted RPCs establish authorization. Supabase Storage enforces a second object boundary tied to database reservations. A Cloudflare Worker executes SSR code and serves responses. Google, Supabase, Cloudflare, manually selected AI providers, webhook operators, and institutional file stores are external processors/trust boundaries.

No browser value—including organization, membership, actor, role, model, job, submission, or object path—is authoritative. No service-role key belongs in the application.

## Principal threats and controls

| Threat                                           | Required control                                                                                | Verification status                                                                         |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Authenticated outsider exploits a privileged RPC | Re-derive actor; reject NULL actor explicitly; scope organization; narrow EXECUTE               | Hardening applied; clean local pgTAP regression passed; hosted hostile-client test required |
| Invitation theft or rebinding                    | Exact confirmed Auth email; immutable claim owner; no domain inference                          | Clean local adversarial pgTAP passed; hosted Auth acceptance required                       |
| Unintended Auth provider creates identities      | Google-only provider configuration; anonymous/manual linking/direct email signup disabled       | Local config inspection; hosted provider test required                                      |
| Forged organization cookie/ID                    | Resolve cookie against live memberships on every route/action; RPC revalidates organization     | Application hardening present; end-to-end multi-org test required                           |
| Cross-organization object references             | Composite same-organization foreign keys plus RLS/RPC checks                                    | Clean migration and local actor-matrix pgTAP passed; hosted inspection required             |
| Sealed metadata/payload disclosure               | Separate listing projection; explicit payload predicate; narrow workspace JSON projection       | Local actor-matrix pgTAP passed; authenticated browser/Storage tests required               |
| Claim race or expired access                     | Row lock, database time, one current claimant, expiry checks in RLS/RPC/Storage                 | Local sequential/time-shift assertions passed; live concurrent test required                |
| Direct workflow-table mutation                   | Revoke writes; expose only state-specific RPCs                                                  | Local RLS/grant assertions passed; hosted hostile-client tests required                     |
| Unsafe upload/path guessing                      | Private bucket, exact randomized reservation, positive extension/MIME checks, limits, no upsert | Repository controls present; Storage API tests required                                     |
| Orphaned or partially deleted files              | Storage API cleanup before guarded metadata deletion; retryable deletion state                  | End-to-end failure/retry test required                                                      |
| Stored XSS/model-output injection                | Plain-text rendering; no `{@html}`; restrictive CSP                                             | Static/build and signed-out local hydration passed; authenticated hosted CSP test required  |
| Open redirect/CSRF                               | `/app`-only return validation; POST mutations; SvelteKit origin checks                          | Unit tests/static inspection; deployed OAuth/CSRF test required                             |
| Sensitive cache/log/notification leakage         | `no-store`; metadata-only records/webhook; no analytics/debug logging                           | Static inspection; hosted headers/log sink test required                                    |
| Server-side request forgery                      | Never server-fetch user URLs; HTTPS validation; links only                                      | Static search; outbound/runtime monitoring remains manual                                   |

## Storage listing

Storage object names are not secrets or authority. BrainSwap does not need bucket listing. The hardening migration checks for Supabase's operation-aware Storage helper, allows SELECT only for exact-object download/info or an authorized delete, and denies list operations. Migration application fails rather than silently accepting an older helper-less Storage schema. The deployed Storage version and list behavior still require explicit verification.

## Abuse cases to retain in tests

- anonymous, uninvited, deactivated, cross-organization, and unrelated members call every public RPC directly;
- an outsider supplies a victim organization and their own invitation email;
- a browser submits another membership, model, job, submission, or object UUID;
- two helpers claim concurrently and the loser attempts payload/file access;
- a claim expires between page load, file upload, and submit;
- an historical helper attempts broader parent/child access than intended;
- a requester follows up from sealed work and attempts implicit file/access inheritance;
- an upload lies about extension, MIME type, size, or finalization metadata;
- Storage deletion partially fails and the caller retries;
- hostile prompt/output/link/filename content is rendered or placed in metadata.

## Residual and external risks

Files are not malware-scanned and declared MIME types can lie. Administrators can access organization content. A compromised authorized account can exercise its legitimate rights. Manual AI-provider use, provider retention/training, scientific validity, collaborator authorization, backups, data residency, incident handling, and institutional policy remain operator responsibilities. Hosted configuration can diverge from migrations. None of these controls make the system absolutely secure.
