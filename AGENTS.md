# BrainSwap contributor guide

## Architecture

- SvelteKit SSR on Cloudflare Pages; TypeScript is strict and shared validation lives in `src/lib`.
- Supabase Auth (Google PKCE), PostgreSQL, and private Storage are the only backend. Server requests use the caller's cookie session—never a service-role key.
- PostgreSQL RLS is the final authorization boundary. Workflow mutations are narrow RPCs that derive actors from `auth.uid()`.
- Organization selection is a convenience cookie and is validated against a live, active membership on every protected request.

## Security invariants

- Exact normalized invitation email only; an Auth user is not membership authorization.
- Never log or notify task bodies, model output, revision instructions, credentials, tokens, or file contents.
- Never integrate with, automate, or accept credentials for model providers. Helpers perform model work manually.
- Sealed content is limited to requester/admin, an unexpired current claimant, and finalized submission authors.
- Uploaded objects remain private, use server-reserved random paths, direct authenticated uploads, explicit allowlists, and 25 MiB/file plus 100 MiB/job limits.
- Render user text as text; never `{@html}`. Never server-fetch user URLs. Mutations are POST plus database authorization.
- Security-definer implementations use `private`, `search_path = ''`, qualified names, and minimal grants.

## Routine commands

`npm run format:check`, `npm run check`, `npm run lint`, `npm test`, `npm run build`, `npm run security:check`, `npm run db:lint`, `npm run test:db`.

## Non-goals

No public signup/community, billing, chat, analytics, model inference/API integration, credential/quota sharing, browser automation, or canonical research-data storage.
