# dartway_auth_providers_shared

The contract of signing in with Google and Apple: `DwSignInWithProvider`, `DwAuthProvider` and the
refusals, shared by the server (`dartway_auth_providers_server`) and the app.

Register it on top of the project's own protocol, so the providers' DTOs join it without
losing its contract version:

```dart
final protocol = DwWireProtocol(dwAuthProvidersProtocolEntries, include: appProtocol);
```

`withRegistration` is the same sign-in with more registration keys — the same token, nonce and
code — which is how an app finishes a sign-up its project refused until the terms are accepted.

Documentation: `docs/4-server/auth-identity.md`.
