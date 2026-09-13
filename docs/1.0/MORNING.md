# Questions for the morning review

Each question names the decision taken meanwhile (see `DECISIONS.md`), so the build did not wait. Answer "ok" or correct.

1. **Wire format (D-002).** JSON with type tags only where needed. Binary later if ever — ok?
2. **relic 2.0.0-rc.1 (D-004).** We build on a release candidate that ships with Serverpod 4. Ok, or stay on relic 1.2 / shelf?
3. **Request kinds and page size (D-005).** Single = not found is a refusal; Maybe = absent is a value; page size fixed by the request class, not by the caller. Ok?
4. **Accounts vs profiles (D-007).** The framework keeps `dw_account` + `dw_identity` (several identifiers per account); the project's profile references the account. Ok?
5. **No joins in the ORM (D-011).** Related rows are loaded in batches. Ok for 1.0, or do you want typed joins now?
6. **Echo to the author (D-018).** I reversed "no echo": updates now reach the connection that ran the command as well, otherwise the author's own screens do not update (the client cannot know which channels a command touched). Ok?
7. **Sessions never expire, only revoked (D-021).** Ok, or do you want an expiry with silent refresh?
8. **Signing in creates the account.** `DwVerifyCode` for an unknown identifier creates the account (the app then asks for a name). A login therefore never records consents; the old flow had separate login/register. Keep "verify creates", or make registration an explicit step that carries consents?
9. **Riverpod stays the public state surface** (`dw.request` → `AsyncValue`). The client engine underneath is pure Dart, so an adapter for another state library is possible later. Ok?
10. **What next, in which order?** Proposal: (a) template on 1.0 + `dartway create`; (b) push; (c) uploads; (d) editable string catalogue in admin; (e) Studio binding; (f) toolkit skills and docs rewrite; (g) deploy on 1.0; then Molodey's migration branch, then U90.

## State at the end of the night

- Branch `dartway-1.0` (local only, not pushed), worktree `../dartway-wt/dartway-1.0`.
- Packages: core 17 tests · orm 117 · generator 25 · server 104 · client 93 (+91 on node) · flutter 65 — all green, analyze clean.
- Example: server compiles, migrates, starts; acceptance 4 tests green; Flutter app 11 tests, web build ok, and it ran against the real server in headless Chrome (sign-in, refusal, live booking, news, chat, admin, sign-out).
- Not yet on 1.0: template, CLI `create`/`deploy`/`check`, toolkit skills, docs outside `docs/1.0`, push, uploads, Studio binding, string catalogue, offline (postponed).
