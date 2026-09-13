# Questions for the morning review

Each question names the decision taken meanwhile (see `DECISIONS.md`), so the build did not wait. Answer "ok" or correct.

1. **Wire format (D-002).** JSON with type tags only where needed. Binary later if ever — ok?
2. **relic 2.0.0-rc.1 (D-004).** We build on a release candidate that ships with Serverpod 4. Ok, or stay on relic 1.2 / shelf?
3. **Request kinds and page size (D-005).** Single = not found is a refusal; Maybe = absent is a value; page size fixed by the request class, not by the caller. Ok?
4. **Accounts vs profiles (D-007).** The framework keeps `dw_account` + `dw_identity` (several identifiers per account); the project's profile references the account. Ok?
5. **No joins in the ORM (D-011).** Related rows are loaded in batches. Ok for 1.0, or do you want typed joins now?
6. **Echo to the author (D-018).** I reversed "no echo": updates now reach the connection that ran the command as well, otherwise the author's own screens do not update (the client cannot know which channels a command touched). Ok?
7. **Sessions never expire, only revoked (D-021).** Ok, or do you want an expiry with silent refresh?
