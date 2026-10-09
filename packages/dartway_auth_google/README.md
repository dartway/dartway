# dartway_auth_google

Sign in with Google for a DartWay app: `DwGoogleAuth.signInCommand()` makes the sign-in command, and
the app sends it like any other.

```dart
// in main, once, before the first sign-in
await DwGoogleAuth.initialize(
  clientId: iosClientId,        // where the platform needs one in code
  serverClientId: webClientId,  // what Android needs to mint an ID token at all
);

final signIn = await DwGoogleAuth.signInCommand(
  introduce: (account) => {
    if (account.displayName case final name?) RegistrationKeys.firstName: name,
  },
);
final result = await dw.command(signIn);
if (result case DwCallOk(value: final session)) await dw.signIn(session);
```

The Google SDK takes its nonce at initialisation, not per sign-in, so `DwGoogleAuth.initialize` makes
one and remembers it; the server checks it against the token. Both client ids must be among the ones
the server is configured with — Android, iOS and the web each have their own, and a token issued for
one the server does not know is refused.

**A refused sign-up is finished without Google.** When the project's `onExternalAccountCreated`
refuses — the terms not accepted yet — the app keeps `signIn` in its state, shows its consent step,
and sends `signIn.withRegistration({...consents})`: the same token and nonce. The token lives about an
hour; `dw.providerCredentialRejected` on a re-send means "ask Google again".

The server half is `dartway_auth_providers_server`. Documentation:
`docs/4-server/auth-identity.md`.
