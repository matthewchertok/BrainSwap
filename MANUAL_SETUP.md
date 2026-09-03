# Manual setup runbook

This is the operator runbook for local verification and the isolated synthetic-data hosted deployment. The current recommendation is `BLOCK PILOT`; completing these steps records evidence but does not itself authorize real research data.

## 1. Confirm the gate and prerequisites

Use an isolated Supabase project and Cloudflare Worker for the pilot. Do not reuse a production or research-data database. Before proceeding, name an operator and incident contact and decide who owns Google, Supabase, Cloudflare, Resend, backups, retention, the optional webhook, and AI-provider approval.

Install:

- Git;
- Node.js 24.15 or later, but still in the Node 24 release line;
- npm;
- Docker or another Supabase-CLI-compatible container runtime; and
- a browser for the manual acceptance test; and
- optionally, `nvm` or another Node version manager.

Verify the runtime:

If `nvm` is installed, select the checked-in version first. Otherwise select a compatible Node 24 release with your version manager.

```sh
nvm use # omit when using a different version manager
node --version
npm --version
```

`node --version` must satisfy `>=24.15.0 <25`.

## 2. Install reproducibly and run application checks

From the repository root:

```sh
cp .env.example .env
npm ci
npm run format:check
npm run check
npm run lint
npm test
npm run security:check
npm run build
npm run deploy:check
git diff --check
```

The copied values are deliberately nonfunctional compile-time placeholders. They let configuration validation, type checking, the build, and Wrangler's non-mutating deployment dry run complete before a local Supabase stack exists; they do not permit login or API access. The build must create `.svelte-kit/cloudflare/_worker.js`. Stop on any failure. Do not use `npm audit fix --force`; review dependency advisories and compatible updates deliberately. Keep `.env` untracked and replace the placeholders with the local values in step 3 before starting the app.

## 3. Start a fresh local Supabase stack

Start Docker, then run:

```sh
npm run db:start
npm run db:reset
npx supabase seed buckets --local --yes
npm run db:lint
npm run test:db
npm run db:types
npx supabase status
```

`db:reset` must apply every migration in filename order. `test:db` must run the complete pgTAP suite, not only structural smoke checks. `db:types` writes `src/lib/types/database.generated.ts`; review its diff and rerun `npm run check`.

Copy the local API URL and local anon/publishable key reported by `supabase status` into an untracked `.env`:

```dotenv
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_PUBLISHABLE_KEY=LOCAL_KEY_FROM_SUPABASE_STATUS
PUBLIC_APP_NAME=BrainSwap
PUBLIC_APP_TAGLINE=Hand off AI jobs when your model cannot finish them.
```

Never place a service-role/secret key in `.env` or application configuration.

## 4. Choose DB-only local testing or configure local Google OAuth

The checked-in `supabase/config.toml` does not enable Google. Without the following deliberate setup, local work is database-only and the browser login flow cannot be tested.

For local OAuth, create a Google **Web application** client for testing. In Google, add this Supabase Auth provider callback as an **Authorized redirect URI**:

```text
http://127.0.0.1:54321/auth/v1/callback
```

BrainSwap does not use Google's JavaScript sign-in flow, so do not add the application origin to Google's Authorized JavaScript origins merely for this server-side PKCE flow.

In a temporary, reviewed local change to `supabase/config.toml`, add:

```toml
[auth.external.google]
enabled = true
client_id = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET)"
skip_nonce_check = false
```

Put the client ID and secret only in the untracked `.env`, restart the local stack, and keep Google consent in testing mode with explicit test users:

```dotenv
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=replace-me.apps.googleusercontent.com
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET=replace-me
```

```sh
npm run db:stop
npm run db:start
npm run db:reset
```

The application callback `http://localhost:5173/auth/callback` belongs in Supabase Auth's redirect allowlist; it is not the Google provider callback. Never commit the Google secret or an adapted local config containing credentials.

## 5. Bootstrap a local organization and exercise login

The bootstrap template contains four values to replace: organization name, normalized slug, exact initial-admin email, and display name. Make a temporary copy outside the repository, edit it, and refuse to execute it if a placeholder remains:

```sh
bootstrap_copy=$(mktemp -t brainswap-bootstrap.XXXXXX)
cp supabase/bootstrap-admin.sql "$bootstrap_copy"
```

After editing `$bootstrap_copy`, run:

```sh
if grep -nE 'REPLACE_WITH|replace-with|example\.invalid' "$bootstrap_copy"; then
  echo 'Bootstrap placeholders remain; do not execute.'
  exit 1
fi
```

Paste the reviewed SQL into the local Supabase Studio SQL editor and execute it once. Run it a second time to verify idempotency. If local OAuth is configured, start `npm run dev`, sign in with the exact invited address, and verify that an uninvited test account is rejected. Use synthetic content only.

## 6. Create and link an isolated hosted Supabase project

For a new environment, create an isolated Supabase project and securely record its project reference, project URL, publishable key, database recovery information, and owner. The current pilot project was created during follow-up setup, but these checks still apply. Do not copy real data into it.

Authenticate and link this checkout:

```sh
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push --dry-run
```

Review the dry run. It must contain only the expected BrainSwap migrations. Do not use `db reset --linked`.

The hardening migration is additive in schema shape, but it deliberately validates stricter invariants. Do not assume it will apply automatically to a populated v0.1 database. First take a recoverable database backup and test the migration against a disposable restored copy. Remediate any legacy HTTP/malformed context URLs, unsupported tool or capability values, inconsistent workflow rows, over-limit or unsafe filenames, and legacy Storage paths before touching the source project. Storage object renames/deletions must use the Storage API, never direct `storage.objects` mutation. For this predeployment repository, a new isolated project from clean migrations is preferred.

## 7. Apply hosted migrations, bucket configuration, types, and bootstrap

After reviewing the dry run:

```sh
npx supabase db push
npx supabase seed buckets --linked --yes
npx supabase gen types typescript --linked > src/lib/types/database.generated.ts
npm run check
```

In the Supabase dashboard verify that:

- every intended exposed table has RLS enabled;
- `job-files` is private;
- the bucket has the 25 MiB and MIME restrictions from `supabase/config.toml`;
- `anon` has no application-table or privileged-RPC access;
- authenticated users lack direct workflow-table mutation grants; and
- only intended authenticated RPCs are callable.

Create and guard a fresh temporary bootstrap copy as in step 5, then paste it into the hosted SQL editor. The script also aborts if its built-in placeholders remain. Do not commit or retain the adapted file. Confirm that the initial models and invitation belong to the expected organization.

## 8. Configure hosted Google OAuth and Supabase redirects

In Google, keep the consent screen in testing mode and add each pilot account as a test user. Request only OpenID, email, and profile. Create a Web application OAuth client.

In Supabase Authentication settings, keep anonymous sign-ins and manual identity linking disabled. Disable direct email/password, magic-link, phone, and every social provider except Google. Leave new OAuth-user creation enabled so an invited Google identity can create its Auth record on first sign-in; database membership still requires the exact confirmed invitation email. The checked-in local config similarly disables direct email signup while allowing Google OAuth identities.

Add the Supabase provider callback shown in Supabase's Google provider page as Google's **Authorized redirect URI**, normally:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

Store the Google client ID and secret only in Supabase Authentication -> Providers -> Google. Do not put the secret in GitHub or Cloudflare.

In Supabase Auth URL Configuration:

- set Site URL to the final HTTPS Worker origin; and
- add exact redirect allowlist entries for `https://YOUR_WORKER_HOST/auth/callback` and any intentional custom-domain callback.

Add `http://localhost:5173/auth/callback` only when local application OAuth is intentionally supported. Preview deployment callbacks should not be wildcarded; add an exact preview URL only for a controlled test, then remove it.

## 9. Create the Cloudflare Workers deployment

This is also a manual cloud action. In Cloudflare **Workers & Pages**, choose **Create application**, connect the private repository through **Workers Builds**, and use:

- production branch: `main`;
- build command: `npm run build`;
- deploy command: `npx wrangler deploy`;
- root path: `/`;
- builds for non-production branches: disabled until preview OAuth redirects are deliberately configured;
- Cloudflare Access: disabled for the application login flow; and
- Node version: `24.15.0` or another version satisfying `>=24.15.0 <25` (the checked-in `.nvmrc` also declares `24.15.0`).

The checked-in `wrangler.jsonc` supplies the Worker entry point, static-assets binding, Node compatibility, and disables preview URLs, observability, Wrangler usage metrics, and dependency instrumentation. Do not let Wrangler auto-configure the repository during deployment. The pinned local Wrangler package and explicit configuration make the deploy step non-interactive.

Set these values as Cloudflare **build variables** so the SvelteKit build can validate them:

```text
NODE_VERSION=24.15.0
PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
PUBLIC_APP_NAME=BrainSwap
PUBLIC_APP_TAGLINE=Hand off AI jobs when your model cannot finish them.
```

Do not add a Supabase service-role/secret key, database password, or Google secret. Configure `NOTIFICATION_WEBHOOK_URL` only if the reviewed build has a reachable metadata-only webhook path, the endpoint owner is known, and failure behavior has been tested.

After the first deploy creates the Worker, open its **Settings -> Variables and Secrets** and add the same four `PUBLIC_*` values as runtime text variables. The application uses dynamic public environment access at request time and intentionally fails closed if the Supabase URL or publishable key is absent. `keep_vars` is enabled in `wrangler.jsonc` so later deployments preserve dashboard-managed runtime values. Do not put secrets in a `PUBLIC_*` variable.

To enable automatic access-request email, create a Resend account and a restricted **sending-access** API key. In the Worker's **Settings -> Variables and Secrets**, add these runtime values; they are not build variables:

```text
RESEND_API_KEY=YOUR_RESEND_KEY                  # Secret
ACCESS_REQUEST_EMAIL_TO=YOUR_OPERATOR_EMAIL    # Secret
ACCESS_REQUEST_EMAIL_FROM=onboarding@resend.dev # Text
```

All three values are required; the login page hides **Request access** until all three validate. Never prefix them with `PUBLIC_`, commit them, or put them in GitHub build variables. The `resend.dev` sender is suitable only when `ACCESS_REQUEST_EMAIL_TO` is the email on the Resend account. To send to any other recipient, verify a domain you own in Resend and use an address at that exact domain for `ACCESS_REQUEST_EMAIL_FROM`. Leave email open/click tracking disabled; the message contains no links.

The Worker sends one plain-text sentence: `<verified Google email> is requesting access to BrainSwap.` A stable hashed idempotency key lets Resend suppress repeats for its documented 24-hour retention window. The request never creates or changes a membership. If any email setting is missing or delivery fails, the requester sees a failure message and remains signed out.

After Cloudflare assigns the `workers.dev` hostname, return to step 8 and set the Supabase Site URL and redirect allowlist to that exact HTTPS origin. Then redeploy once and inspect the deployed response headers before login testing.

## 10. Invite pilot users and complete synthetic acceptance

Sign in as the exact bootstrap admin. In `/app/admin`, add exact invitation emails for at least a requester, two competing helpers, and a separate cross-organization test account/organization. Adding an invitation grants eligibility but does not send an email automatically. For an unclaimed invitation, **Email approval** opens the administrator's mail application with a short approval message addressed to that person; the administrator must review and send it. Verify each membership, role, and organization before proceeding.

Before inviting one synthetic account, use **Request access** with that account. Confirm the operator receives exactly the one-line request, the requester remains unable to open `/app`, and a repeat request within 24 hours produces no duplicate email. Then review the exact address and add it manually in `/app/admin`.

Run [docs/acceptance-test.md](docs/acceptance-test.md) using dummy tasks and files. Record tester, timestamp, commit, browser, expected/actual result, response headers, and screenshots that contain no sensitive payload. Any authorization, Storage, deletion, OAuth, CSP, or cross-organization failure keeps the recommendation at `BLOCK PILOT`.

Only after all automated and manual gates pass may the lab reassess whether the system is suitable for a limited synthetic or real-data pilot. Real unpublished research remains explicitly blocked under the current audit recommendation.
