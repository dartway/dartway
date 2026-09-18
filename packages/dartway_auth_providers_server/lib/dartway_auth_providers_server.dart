/// Sign in with Google and Apple on a DartWay server.
///
/// The app gets a token from the provider's own SDK and sends it with
/// `DwSignInWithProvider`; this module verifies it against the keys the
/// provider publishes — signature, issuer, the app's client ids, expiry,
/// nonce — and signs in the account of the subject it proves, creating one
/// the first time through `DwAuthConfig.onExternalAccountCreated`.
///
/// See `docs/4-server/auth-identity.md`.
library;

export 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';

export 'src/dw_id_token_check.dart' show DwProviderClaim;
export 'src/dw_jwks_cache.dart'
    show DwJwksCache, DwJwksDocument, DwJwksFetch, DwJwksUnavailable;
export 'src/dw_sign_in_providers.dart'
    show DwAppleSignIn, DwGoogleSignIn, DwSignInProvider;
export 'src/dw_sign_in_providers_module.dart' show DwSignInProvidersModule;
