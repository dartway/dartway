# dartway_auth_apple

Sign in with Apple for a DartWay app: `dw.signInWithApple()`.

```dart
final result = await dw.signInWithApple(
  introduce: (person) => {
    // Apple tells the name once in a lifetime, and only here.
    if (person.givenName case final name?) RegistrationKeys.firstName: name,
  },
);
```

It makes the nonce (the hash to Apple, the raw value to the server, which accepts either and refuses
anything else), carries Apple's one-time `authorizationCode` — the only thing that can later revoke
this person's tokens when they delete their account — and signs the answered session in.

The server half is `dartway_auth_providers_server`. Documentation:
`docs/4-server/auth-identity.md`.
