# dartway_auth_providers_shared

The contract of signing in with Google and Apple: `DwSignInWithProvider`, `DwAuthProvider` and the
refusals, shared by the server (`dartway_auth_providers_server`) and the app.

Register it in the protocol both sides build:

```dart
final appProtocol = DwWireProtocol([
  ...dwAuthProvidersProtocolEntries,
  ...
], include: DwWireProtocol.core);
```

Documentation: `docs/4-server/auth-identity.md`.
