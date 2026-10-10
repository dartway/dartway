# dartway_auth_apple

Sign in with Apple for a DartWay app: `DwAppleSignIn.signInCommand()` makes the sign-in command, and
the app sends it like any other.

```dart
final signIn = await DwAppleSignIn.signInCommand(
  introduce: (person) => {
    // Apple tells the name once in a lifetime, and only here.
    if (person.givenName case final name?) RegistrationKeys.firstName: name,
  },
);
final result = await dw.command(signIn);
if (result case DwCallOk(value: final session)) await dw.signIn(session);
```

It makes the nonce (the hash to Apple, the raw value to the server, which accepts either and refuses
anything else) and carries Apple's one-time `authorizationCode` — the only thing that can later revoke
this person's tokens when they delete their account.

**A refused sign-up is finished without Apple.** When the project's `onExternalAccountCreated`
refuses — the terms not accepted yet — the app keeps `signIn` in its state, shows its consent step,
and sends `signIn.withRegistration({...consents})`: the same token, nonce, code and introduced name.
Running Apple again is not the way back: Apple would not tell the name a second time. The token lives
about ten minutes; `dw.providerCredentialRejected` on a re-send means "ask Apple again".

The server half is `dartway_auth_providers_server`. Documentation:
`docs/4-server/auth-identity.md`.
