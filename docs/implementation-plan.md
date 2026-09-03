# MVP implementation and verification plan

Status date: 2026-09-03 (America/New_York)

This is a status document, not a statement that the application is deployment-ready. `Implemented` means code is present. `Locally executed` means a command was run in the audit environment. `Manual` means a hosted operator must verify it. The current release gate is `BLOCK PILOT`.

## Workstreams

| Workstream                           | Repository status                                                                                                                                                                                                                             | Verification still required                                                                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| SvelteKit/Cloudflare scaffold        | Implemented; format/type/lint/unit/security/build pass, limited signed-out desktop/mobile localhost preview, and deployed Worker creation completed                                                                                           | Full authenticated desktop/mobile, keyboard, and external-link tests                                                                        |
| Supabase schema and RLS              | Fresh reset applied all three migrations; SQL lint passed; the expanded adversarial pgTAP suite passed 264/264 locally                                                                                                                        | Hosted policy/configuration inspection and authenticated hostile-client acceptance                                                          |
| Google/PKCE authentication           | Login, callback code exchange, verified-claims hook, restricted return paths, no-store responses, and hosted invited-admin sign-in completed                                                                                                  | Uninvited/deactivated/multi-org negative cases and sign-out/back-cache tests                                                                |
| Membership and organizations         | Exact-email claim, immutable claim-owner field, selected-organization enforcement, administrator update/deactivation, and last-admin guard implemented                                                                                        | Hosted authenticated invite theft, deactivation, last-admin, and cross-organization acceptance                                              |
| Jobs and results                     | Partial drafts, sealed-by-default publication, free-form model preferences, publish/claim/release/extend/submit/revise/accept/cancel/reopen, and author-only in-place result correction before the requester's first response are implemented | State-transition matrix, edit-lock race, expiry, history, and browser workflow tests                                                        |
| Sealed content                       | Explicit listing/workspace projections and separate payload/result authorization are present; local actor-matrix pgTAP tests passed                                                                                                           | Authenticated browser and hosted Storage verification                                                                                       |
| Files                                | Job/result and profile-photo reservation, direct upload, finalization, authorized download, retryable cleanup, visible upload tables, and deletion paths implemented                                                                          | End-to-end Storage tests, edit-lock cleanup races, failure recovery, and quota accounting against local and hosted services                 |
| Follow-up jobs                       | Requester action, same-organization parent provenance, finalized-result snapshot, and no implicit file copy implemented                                                                                                                       | Actor tests and browser confirmation that parent authorization is not inherited                                                             |
| Administration/profile/notifications | Unclaimed-invitation removal, profile bio/organization/photo/fixed model catalog, safe in-app job notifications, metadata webhook, Google-verified minimal Resend access requests, and manual prefilled approval links are implemented        | Admin/photo actor matrix, access-request email delivery/failure/duplicate hosted tests, and approval-link review; new-job email is deferred |
| Documentation and operations         | Runbook, threat model, acceptance plan, and audit report updated; clean local database gates completed                                                                                                                                        | Execute the hosted runbook and record synthetic-data acceptance evidence                                                                    |

## Required release sequence

1. Complete focused corrections without bypassing RLS or adding an elevated Supabase credential; keep the narrowly scoped email key server-only.
2. Reset a clean local Supabase stack and apply every migration in order.
3. Run SQL lint and the complete pgTAP adversarial matrix.
4. Regenerate database types and run all application checks on supported Node 24.
5. Deploy only with synthetic data to an isolated pilot project.
6. Verify Google OAuth, invitations, organization selection, RLS, Storage, headers, deletion recovery, and browser layouts.
7. Resolve every critical/high finding and any failed acceptance item.
8. Obtain lab approval for data classification, providers, retention, backups, and incident response.
9. Reassess the recommendation. Do not admit real unpublished research while it remains `BLOCK PILOT`.

## Design decisions

- SQL functions own workflow transitions; browser clients do not receive direct workflow-table mutation grants.
- The organization cookie is a UUID selection hint, never authority.
- Public RPCs derive actors from `auth.uid()` and use explicit NULL-safe authorization.
- Files upload browser-to-Supabase only after an exact metadata reservation; deletion calls the Storage API before guarded database cleanup.
- External links are displayed but never fetched or previewed.
- Published jobs have one sealed mode. Only listing metadata is organization-visible before an authorized claim; prompt, chat link, and files stay protected.
- Job model preferences are bounded free-form text. Profile model availability uses the fixed organization-scoped catalog.
- A submitted result may be corrected in place only by its author until the requester's first workflow response; database locks serialize that boundary.
- User/model material is plain text. Notification and audit metadata remain payload-free.
- An access request proves the address through the primary Google identity, sends only that normalized address through a server-only email provider, signs the outsider out, and never creates a membership.
- A follow-up stores an intentional text snapshot for provenance but inherits no parent-file or parent-access authorization.
