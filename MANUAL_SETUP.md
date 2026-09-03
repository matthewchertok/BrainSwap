# Manual setup runbook

## 1. Local prerequisites

Install Node.js 20+ (current active LTS is recommended), npm, and a Docker-compatible runtime. The project installs the Supabase CLI as a development dependency. Run:

```sh
npm ci
cp .env.example .env
npm run db:start
npm run db:reset
npm run test:db
npm run dev
```

Copy the local URL and anon/publishable key printed by `npx supabase status` into `.env`. Run `npm run db:stop` when finished. Use `npm run db:types` after schema changes.

## 2. Hosted Supabase

1. Create a project and securely record its reference, project URL, publishable key, database password, and recovery details.
2. Authenticate/link/push from this directory:
   ```sh
   npx supabase login
   npx supabase link --project-ref YOUR_PROJECT_REF
   npx supabase db push
   npx supabase seed buckets --linked
   npx supabase gen types typescript --linked > src/lib/types/database.generated.ts
   ```
3. Copy `supabase/bootstrap-admin.sql`, replace organization name, normalized slug, exact initial-admin email, and display name placeholders, review it, and execute it in the Supabase SQL editor. Never commit the adapted file.
4. In Table Editor/SQL, confirm every public application table reports RLS enabled and `job-files` is private with the configured size/MIME restrictions. Confirm authenticated clients lack direct workflow-table update/delete grants.

## 3. Google OAuth

1. Create a Google Cloud project and OAuth consent screen suitable for a small testing deployment. Keep it in testing and add pilot accounts as test users when Google requires it.
2. Request only OpenID, email, and profile. Create a **Web application** OAuth client.
3. Add `http://localhost:5173` and the eventual `https://YOUR_PROJECT.pages.dev` as authorized JavaScript origins.
4. In Supabase Authentication → Providers → Google, copy the displayed Supabase callback URL (normally `https://YOUR_REF.supabase.co/auth/v1/callback`) into Google's authorized redirect URIs.
5. Put the Google client ID and secret only in Supabase's Google provider settings. Never put the secret in this repository or Cloudflare.

## 4. Supabase Auth URLs

Set the Site URL to the production Pages origin. Add exact redirect allowlist entries for:

- `http://localhost:5173/auth/callback`
- `https://YOUR_PROJECT.pages.dev/auth/callback`
- the production application `/auth/callback` if distinct.

Application origins belong in Google, while application callback paths belong in Supabase. Add any preview URL only when intentionally used. A later custom domain requires adding its origin/callback to both systems.

## 5. Cloudflare Pages

1. Connect the private GitHub repository; create Pages with production branch `main`, build command `npm run build`, and output `.svelte-kit/cloudflare`.
2. Configure `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `PUBLIC_APP_NAME`, and `PUBLIC_APP_TAGLINE`; optionally configure server-only `NOTIFICATION_WEBHOOK_URL`. Do not add database/service keys or Google secrets.
3. Deploy, note the assigned `pages.dev` address, then add it to the Google origins and Supabase URL lists above. No custom domain is required for the pilot.

## 6. Initial users

Sign in with the exact bootstrap-admin address and confirm callback claiming reaches `/app`. In `/app/admin`, add the exact addresses of two pilot users; no email is sent. Add them as Google test users when needed. Each signs in and completes display name, models, capabilities, and notifications on `/app/profile`.

## 7. Custom domain later

Attach (for example) `brainswap.io` to the existing Pages project via Cloudflare Custom domains; no app rebuild or database migration is required beyond redeployment with desired branding. Add `https://brainswap.io` to Google authorized origins, `https://brainswap.io/auth/callback` to Supabase redirects, update Supabase Site URL if canonical, and verify CSP/Supabase settings and OAuth end-to-end before switching links.

Cloud accounts, secrets, DNS, OAuth approval, webhook ownership, data retention/backups, and institutional approval cannot be configured from this repository. Run `docs/acceptance-test.md` with synthetic content before real data.
