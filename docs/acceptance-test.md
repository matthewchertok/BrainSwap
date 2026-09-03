# Initial pilot acceptance test

Use synthetic, non-sensitive fixtures. **Do not place real unpublished research in the pilot until this test passes and the lab has approved the data-use boundary.** Record tester, timestamp, expected/actual result, and screenshots without payload content.

1. Bootstrap admin signs in; an uninvited Google account is denied and signed out.
2. Admin adds two exact-email testers; both sign in and complete model/capability preferences.
3. Requester creates a sealed draft, adds inline context and an HTTPS institutional link, reserves/uploads/finalizes a small PDF.
4. Confirm an unrelated tester cannot inspect its payload, context, or exact file path/download.
5. Requester publishes and cannot claim their own job.
6. Have two helpers claim concurrently; exactly one succeeds. The winner sees/downloads context; loser still cannot.
7. Winner copies the runnable prompt, creates a submission draft, uploads/finalizes a result file, and submits a response.
8. Requester sees an in-app notification and complete immutable response, then requests a revision.
9. Original helper sees the request and submits a second immutable result; requester accepts it.
10. Requester creates a follow-up; confirm it has a response text snapshot but grants no accidental access to inaccessible parent data/files.
11. Create an allowed-state disposable job and delete it; inspect Storage first to confirm objects were removed before database records.
12. Confirm signed-out access to its known URL redirects to login.
13. Deactivate a tester while their session is live; refresh and confirm immediate loss of access and safe invalidation/release behavior.
14. Repeatedly refresh protected pages and inspect response headers/browser cache; confirm no payload is cached.
15. Repeat essential layout/workflow checks using keyboard-only navigation at desktop width and an iPhone-sized viewport.
