/// The contract of signing in with Google and Apple: what the app sends, and
/// what it may be told back.
///
/// The server half is `dartway_auth_providers_server`, which verifies the
/// provider's token; see `docs/4-server/auth-identity.md`.
library;

export 'src/dw_sign_in_with_provider.dart';
