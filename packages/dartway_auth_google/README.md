# dartway_auth_google

Sign in with Google for a DartWay app: `dw.signInWithGoogle()`.

```dart
// in main, once, before the first sign-in
await DwGoogleAuth.initialize(
  clientId: iosClientId,        // where the platform needs one in code
  serverClientId: webClientId,  // what Android needs to mint an ID token at all
);

final result = await dw.signInWithGoogle(
  introduce: (account) => {
    if (account.displayName case final name?) RegistrationKeys.firstName: name,
  },
);
```

The Google SDK takes its nonce at initialisation, not per sign-in, so `DwGoogleAuth.initialize` makes
one and remembers it; the server checks it against the token. Both client ids must be among the ones
the server is configured with — Android, iOS and the web each have their own, and a token issued for
one the server does not know is refused.

The server half is `dartway_auth_providers_server`. Documentation:
`docs/4-server/auth-identity.md`.
