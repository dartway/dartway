## 8. Sign-in hooks and accounts

For a closed application, `beforeCodeSignIn(ctx, accountId, kind, identifier)`
checks current project admission for every correct sign-in code, including an
existing account. It runs inside verification's transaction before key issuance;
refusal rolls back ticket consumption and new-account creation. Lock the project
admission row here (`SELECT … FOR UPDATE`). Withdrawal changes that row first,
then calls `ctx.accounts.revokeKeys` in the same transaction; `revokeKeys` takes
no account lock, so revoking before the row change leaves a key issued in
between. Never
rely on delivery filtering or `onAccountCreated` alone: a previously delivered
code and an existing account bypass those checks. The hook is not invoked for
external-provider authentication or identifier attachment. No outbound effects
inside the hook; the transaction may retry.

The framework owns accounts, identifiers and keys; `DwAuthConfig` (the skeleton's
`lib/src/account/logic/auth.dart`) is the project's part:

- `normalize` — the identifier's one form, the shared function the app applies too;
- `generateCode` (`null` = random digits) and `deliverCode` — always called, after the ticket commits,
  on a fresh pooled `ctx.db`, not the ticket's transaction: a throw or a refusal there does not undo the
  ticket. Deciding not to send (a fixed test code) is its own choice;
- **`onAccountCreated` creates the profile row in the account's transaction**; refusing there refuses
  the sign-in. `origin` is `DwSignInOrigin` (check consents there) or `DwToolOrigin` (`ensure`);
- **`accountDeletion`** is required: `byMember` answers `DwDeleteMyAccount` (app stores require it),
  `byOperator` leaves it to `ctx.accounts.deleteAccount` — switch member deletion off that way, never by
  refusing in `onAccountDeleting`, which would refuse the operator too;
- **`onAccountDeleting` deletes or anonymises the project's rows** — every row referencing `dw_account`
  without a cascade — per kind, by one question: is this about that person alone (delete it), or does
  someone else hold on to it (keep the row, blank the profile — a tombstone: its account column nullable
  with `DwOnDelete.setNull`, every personal field cleared, `deletedAt` stamped, `isDeleted` on the data
  objects)? Never a `hidden` flag with the personal data still in it; the app says which route before
  asking to confirm. The server refuses to start while a project table cascades from `dw_account` with
  no hook. Worked example, in the framework repository's example (on GitHub, not in this project):
  [`account/logic/auth.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/account/logic/auth.dart);
- `onExternalAccountCreated` — the profile for a Google/Apple sign-in, required to allow one; the
  verified claims are in `registration` under `DwProviderClaim` keys, which the app cannot write;
- `linkByVerifiedEmail` — off by default, and off is the safer default; on, it links both ways: a
  provider's first sign-in to an existing e-mail account, and an e-mail code to the account a provider
  proved the address for; `onIdentifierChanged` — mirror or republish an identifier, in the changing
  transaction.

Google and Apple sign-in is `DwSignInProvidersModule([DwGoogleSignIn(clientIds: [android, ios, web]),
DwAppleSignIn(clientIds: [bundleId], signingKey: …)])` in `modules:` — one client id per platform — with
`dwAuthProvidersProtocolEntries` in both protocols; the project never verifies a token itself. Apple's
`signingKey` (the `.p8`, from the secret store) lets a deletion revoke the Apple token (App Store
5.1.1(v)); Apple tells the name only at the first authorization, so the app sends it then. The app half
is `dartway_auth_google` / `dartway_auth_apple`: `DwGoogleAuth.signInCommand()` /
`DwAppleSignIn.signInCommand()` make the `DwSignInWithProvider`, and the app sends it with `dw.command`
and `dw.signIn` like `DwVerifyCode`. A sign-up `onExternalAccountCreated` refuses (`consentsRequired`)
is finished by sending `withRegistration({...consents})` of the same held command — never by running
the provider again (Apple would not tell the name twice). `dw.providerUnreachable` may be retried,
`dw.providerCredentialRejected` may not: the token expired (Google ~1 h, Apple ~10 min), ask the
provider again. Details:
[`auth-identity.md`](https://github.com/dartway/dartway/blob/master/docs/4-server/auth-identity.md).

**Everything else about accounts is `DwAccountService`** — `ctx.accounts` in a handler, job, route or
startup step (joins its transaction), `server.accounts` beside a started server,
`DwAccountService(db, auth)` in a script — never SQL on `dw_*` tables: `ensure`, `find`,
`listIdentities(Of)`, `accountsMatching`, `updateIdentifiers`, `moveIdentities`, `removeIdentities`, keys (`dartway-access`).

Trusted admin/backend edits use `ctx.accounts.updateIdentifiers(accountId, {phone, email,
beforeChange})`: phone/e-mail are `DwFieldPatch<String>` keep/set/clear, both changes atomic,
returning all final identities. Enforce the caller's project access rule yourself; this neither
creates/merges an account nor changes the caller or session keys. Read the project profile without
locking first; lock/revalidate and write it **only inside beforeChange**, through its passed
transaction context. Do not take the profile lock before account/identifier locks. The callback
runs after conflict/last-login validation, then all identifier SQL runs before any identifier hook.
No outbound/nontransactional effects in callbacks/hooks: the enclosing transaction may retry.
Invalid input refuses `dw.invalid` on phone/email; occupied values `dw.identifierTaken` on that
field; clearing the final login method `dw.invalid` on the composite `identifiers` field. Provider identities count as logins.
New/changed values have no code proof; a no-op preserves proof and emits no hook. Hooks use
`DwIdentifierChangeCause.updated` only for actual changes (including duplicate removals); a valid
all-keep call still runs the profile callback. Publish profile-only changes explicitly when no hook
ran. A failure rolls back callback writes and both identifiers; never SQL on framework tables.
