# Pre-pilot acceptance test

Use only synthetic, non-sensitive fixtures. The current audit recommendation is `BLOCK PILOT`; this document is a test plan, not a record that the cases passed.

## Evidence record

Create a copy of this table for every run:

| Field                                         | Value |
| --------------------------------------------- | ----- |
| Commit SHA                                    |       |
| Environment/project                           |       |
| Tester and date/time zone                     |       |
| Browser/OS and viewport                       |       |
| Supabase migration versions                   |       |
| Expected result                               |       |
| Actual result                                 |       |
| Status (`PASS`, `FAIL`, `NOT RUN`, `BLOCKED`) |       |
| Evidence location                             |       |

Screenshots, logs, and exports must not contain task bodies, model responses, revision instructions, tokens, OAuth codes, sensitive URLs, filenames, or file contents. A UI-hidden control is not proof of authorization; exercise the corresponding RPC/table/Storage request directly with the caller's ordinary session where practical.

## Required synthetic identities

Prepare separate browser profiles/accounts for:

- Org A administrator;
- Org A requester;
- Org A helper 1;
- Org A helper 2;
- Org A unrelated active member;
- Org B administrator/member;
- authenticated but uninvited account; and
- a membership that will be deactivated during the test.

Use distinct exact email addresses. Do not infer eligibility from an email domain. Create a second organization explicitly for cross-organization testing.

## 1. Automated gates

From a clean checkout on supported Node 24:

```sh
cp .env.example .env
npm ci
npm run format:check
npm run check
npm run lint
npm test
npm run security:check
npm run build
git diff --check
```

With Docker running, start from fresh migrations rather than a pre-existing local database:

```sh
npm run db:start
npm run db:reset
npm run db:lint
npm run test:db
npm run db:types
npm run check
```

Record exact command output and test counts. Any skipped database gate is `NOT RUN`, not a pass.

## 2. Authentication and invitation boundary

1. Request a known `/app/jobs/<uuid>` URL while signed out. Expect a redirect to login and no application data in the response.
2. Begin Google sign-in with a crafted `next` value for an external origin, protocol-relative URL, encoded backslash, control character, `/login`, and `/application`. Expect every case to return only to `/app` or an `/app/...` descendant.
3. Sign in with the uninvited account. Expect membership claiming to return no membership, the Supabase session to be signed out, and `/app` to remain inaccessible.
4. With an uninvited Google account, choose **Request access**. Confirm the operator receives exactly `<normalized email> is requesting access to BrainSwap.`, the requester is signed out, and no membership or organization data is created or returned.
5. Repeat that request within 24 hours. Confirm Resend's idempotency handling produces no second email. Confirm the idempotency header does not contain the raw requester address.
6. Use ordinary **Sign in with Google** with another uninvited account. Confirm it sends no access-request email. Temporarily remove one email setting and simulate a Resend non-2xx response; request delivery must fail closed, reveal no provider detail, create no membership, and leave the account signed out.
7. Invite an address with mixed case/outer whitespace only through the documented normalized path. Confirm only the exact confirmed Auth email claims it and that adding the invitation itself sends no email. Before that account claims the invitation, confirm **Email approval** opens the administrator's mail application with the normalized address, subject `BrainSwap access approved`, and only the documented plain-text approval sentence. Confirm BrainSwap does not send the message automatically.
8. Attempt to claim that invitation with another account and attempt to rebind a previously claimed membership. Expect both to fail.
9. Sign out through POST. Refresh and use the Back button; protected content must not be restored from a shared/browser cache.
10. Force a membership-query error in a disposable environment. Protected routing and access requests must fail closed rather than treating the error as an empty membership result.
11. Inspect Supabase Auth providers and attempt direct email/password, magic-link, phone, anonymous, and unused social-provider sign-in requests. Only a primary verified Google identity may create/sign in an identity or trigger an access-request email; an uninvited identity must still receive no application access.

## 3. Organization and administrator isolation

1. Give one account active memberships in Org A and Org B. Select Org B, then create/update a job, profile, invitation, membership, model choice, and notification. Confirm every object/change stays in Org B.
2. Replace the organization cookie with Org A, Org B, a random UUID, and a victim UUID unavailable to the account. Expect only currently active memberships to be selectable.
3. As an Org B member, call every public Org A RPC with known Org A organization/job/membership/model/file UUIDs. Expect no data or mutation.
4. As an authenticated uninvited account, call `admin_upsert_membership` with the victim organization and the attacker's email/`admin` role. Expect a hard authorization error and no invitation row.
5. As an ordinary Org A member, call each admin RPC directly. Expect failure.
6. As Org A admin, attempt to update an Org B membership. Expect failure.
7. Attempt to deactivate/demote the last active Org A administrator. Expect rejection. Add a second admin, then confirm an allowed demotion/deactivation succeeds without rebinding its Auth owner.
8. Confirm ordinary members cannot select raw invitation emails, role-management fields, or administrator audit records.

## 4. Draft, listing, and sealed-content visibility

1. As requester, create a `claimed_only` draft containing unique canary strings in the task, success criteria, output format, sensitivity notes, context, URL, and filename.
2. Before publication, query the job/workspace as requester, admin, unrelated member, Org B member, and uninvited account. Only requester/admin may see the draft.
3. Publish it. An unrelated active Org A member may see only intended listing fields such as title, listing summary, status, effort, model/tools, and requester display name.
4. Search the unrelated member's HTML, serialized page data, RPC JSON, notifications, and Storage responses for every canary. None may appear.
5. Specifically verify that `sensitivity_notes`, organization/internal membership IDs, protected contexts, exact Storage paths, result text, and revision instructions are absent before authorization.
6. For a separate `lab` job, verify the task/context visibility explicitly chosen by the product, while results and revision instructions remain limited to intended participants.

## 5. Claim concurrency, expiry, and deactivation

1. Confirm the requester cannot claim their own job through either UI or direct RPC.
2. Have helper 1 and helper 2 submit `claim_job` at the same time from separate browser profiles. Exactly one succeeds.
3. The winner can access protected payload/files; the loser and unrelated member cannot. A failed race must reveal no protected data.
4. Set up an expired claim using a test-only database fixture or controlled clock/data change. Confirm the expired claimant immediately loses claimant-only workspace and Storage access even if their ID remains on historical rows.
5. Confirm another eligible helper can atomically replace the expired claim and the prior helper cannot release, extend, finalize a file, or submit.
6. Confirm a claimant cannot submit after expiry unless the documented workflow has first granted a new valid claim.
7. Deactivate the current claimant while their Auth session remains live. Refresh and directly call RPC/Storage APIs. Expect immediate application-data denial and a consistent job state that another helper can recover.

## 6. Submission, revision, acceptance, cancellation, and reopening

1. Current claimant creates a result with a unique model name, response, notes, and tools. An unrelated/helper loser/requester must not submit on the claimant's behalf.
2. Submit revision 1. Confirm it becomes immutable, receives a unique positive revision number, and the job leaves the claimed state with claim fields cleared as documented.
3. Attempt direct UPDATE/DELETE of the submitted row. Expect denial.
4. Requester requests revision with nonblank bounded instructions. Unrelated members, the helper, and cross-org users must fail.
5. Verify only intended principals can read revision instructions. Submit revision 2 and confirm revision 1 is retained unchanged.
6. Requester accepts the latest submission. Confirm `accepted_submission_id` references a finalized submission and accepted work rejects further claim, submit, revision, cancellation, or reopen transitions unless the documented product explicitly permits one.
7. On separate jobs, test cancellation and each permitted reopen source state. Confirm impossible/out-of-order transitions fail at the RPC/database boundary.
8. Confirm cancellation and reopening clear assignment/expiry fields consistently.

## 7. Job and result file lifecycle

For both a requester job file and claimant result file, test reservation -> upload -> finalization -> authorized download -> cleanup/delete.

1. Reserve a small allowed file. Confirm the returned path is random/server-generated, contains no raw traversal, and is scoped to the correct organization/job.
2. Upload only to that exact path with `upsert: false`; finalize it; download it as each intended principal.
3. Attempt an unreserved path, guessed path, another organization path, another user's reservation, overwrite/upsert, wrong bucket, wrong size, wrong MIME, and finalization before upload. Expect failure.
4. Attempt zero-byte, >25 MiB, aggregate >100 MiB including pending reservations, HTML, SVG, script, executable, generic binary, and macro-enabled Office files. Expect rejection at reservation/upload/finalization as applicable.
5. Confirm pending metadata is not exposed as a ready download and published work cannot silently include pending uploads.
6. Call Storage list as requester, claimant, unrelated member, and cross-org member. Expect the operation-aware policy to deny listing or return no object rows for every caller, including callers who may download a known exact object.
7. Expire/deactivate the claimant and repeat result-file download/finalize/delete attempts. Expect the same loss of authority as workspace access.
8. Delete a disposable job through the application. Simulate partial Storage failure, retry, and confirm cleanup is idempotent. Database deletion must refuse while related Storage objects remain, then succeed after Storage API cleanup without orphaned objects/metadata.
9. Confirm no normal application SQL directly deletes `storage.objects` metadata.

## 8. Follow-up provenance

1. From a finalized parent result, requester creates a follow-up draft.
2. Confirm `parent_job_id` is same-organization and the child contains an intentional text snapshot of the selected finalized response.
3. Confirm the child grants no access to parent sealed payload, contexts, revision instructions, object paths, or files.
4. Confirm files/links are not silently duplicated; requester must intentionally attach or link them.
5. As a requester in another organization or an unauthorized parent participant, attempt to create/reference the parent. Expect failure.

## 9. Notifications, webhook, audit, and logging

1. Exercise publish, claim, submit, revision, accept, cancellation, expiry replacement, and administrative changes.
2. Inspect notification text, webhook bodies, audit metadata, Cloudflare logs, and Supabase logs. They may contain safe identifiers/event types but no task/result/revision/file content, credentials, OAuth codes/tokens, sensitive URLs, access-request addresses, or email bodies. Resend's own transactional record necessarily contains the operator address and the one-line requester address; verify it contains nothing else.
3. Confirm the requester is excluded from new-job notifications and inactive members are not treated as active recipients. The MVP does not claim capability/model matching.
4. If a webhook is configured, force timeout/non-2xx/unreachable behavior. The already-committed core transition must remain successful and no secret may reach client JavaScript.
5. Confirm there is no analytics or tracking request.
6. Confirm the Resend key and recipient are absent from browser JavaScript, HTML, network requests, build output, and Git. Confirm the access-request email is plain text and has no tracking link or pixel.

## 10. Headers, caching, accessibility, and responsive smoke tests

At desktop width and an iPhone-sized viewport, test login, organization selection, dashboard, new job, sealed detail before/after claim, submission, revision, admin, profile, notifications, file actions, follow-up, and deletion.

On the dashboard, change tabs over a throttled connection. The selected tab must update immediately, a visible loading status must be announced, and the prior results must remain clearly pending until the server-authorized response arrives.

Create and edit a draft with a deadline. Confirm the browser provides a native local date-and-time picker, the stored instant displays in local time when editing, and malformed, unzoned, missing-conversion, and past values still fail server-side validation.

Confirm job status is non-interactive text with a visible dot: amber for **Open** and green for **Submitted**. Keyboard and pointer interaction must not suggest that the status is a button.

For protected/auth responses verify:

- `Content-Security-Policy` permits required SvelteKit/Supabase behavior without console violations and includes frame/object restrictions;
- `form-action` permits only the application, the configured Supabase origin, and `https://accounts.google.com`, and a Google sign-in click visibly leaves the login page;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: same-origin`, a matching document-level referrer policy, and a restrictive `Permissions-Policy`;
- frame denial; and
- `Cache-Control: no-store, private` where sensitive/session state is involved.

Use keyboard-only navigation, visible focus, labels, error announcements, zoom, long hostile text, and narrow viewport wrapping. Open external links and confirm safe target/rel/referrer behavior. Confirm no user/model content is interpreted as HTML.

## Release decision

Any critical/high authorization failure, skipped clean-database suite, OAuth/Storage failure, CSP breakage, cross-organization leak, or orphaning deletion defect means `BLOCK PILOT`. Record every `NOT RUN` item explicitly. Real unpublished research data remains prohibited until all blocking findings are fixed, automated gates pass, hosted acceptance passes with synthetic data, and the lab approves the data boundary.
