/// Sign in with Google for a DartWay app: `dw.signInWithGoogle()`.
///
/// The server half is `dartway_auth_providers_server`, which verifies the
/// token; see `docs/4-server/auth-identity.md`.
library;

export 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInAccount, GoogleSignInException, GoogleSignInExceptionCode;

export 'src/dw_google_sign_in.dart';
