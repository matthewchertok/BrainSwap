# MVP v0.1 implementation plan

1. **Scaffold/tooling** — strict SvelteKit/Cloudflare project, lint/format/test/CI, centralized branding.
2. **Database boundary** — organization-scoped schema, constraints/indexes, private authorization helpers, RLS/grants, Storage policies, atomic RPC workflows, bootstrap data, pgTAP tests.
3. **Authentication** — SSR cookie client, verified claims, Google PKCE callback, exact-email claiming, active-organization selection.
4. **Workflow and files** — drafts through terminal states, claim leases, immutable revisions, server reservations/direct Storage upload/finalization, cleanup-before-delete.
5. **Interface** — responsive protected dashboard, job editor/workspace/history, profile/admin, notification inbox, safe exports.
6. **Hardening and delivery** — validation/security headers, tests, threat review, setup/acceptance documentation, production build.

## Decisions

- SQL functions own state transitions; ordinary clients receive read grants but no direct workflow-table writes.
- The selected organization cookie is an opaque UUID hint, never authority.
- Files upload browser-to-Supabase after a metadata reservation; deletion calls Storage before an RPC removes records.
- User material is plain text. External links are displayed but never fetched or previewed.
- Email/webhook notifications are metadata-only and webhook delivery is best effort after committed transitions.
