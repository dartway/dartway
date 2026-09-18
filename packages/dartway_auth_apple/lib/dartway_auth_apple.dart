/// Sign in with Apple for a DartWay app: `dw.signInWithApple()`.
///
/// The server half is `dartway_auth_providers_server`, which verifies the
/// token and keeps what a deletion needs; see
/// `docs/4-server/auth-identity.md`.
library;

export 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show
        AppleIDAuthorizationScopes,
        AuthorizationCredentialAppleID,
        AuthorizationErrorCode,
        SignInWithAppleAuthorizationException,
        SignInWithAppleException,
        WebAuthenticationOptions;

export 'src/dw_apple_sign_in.dart';
