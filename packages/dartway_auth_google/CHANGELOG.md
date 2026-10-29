## Unreleased

- **Web sign-in.** `DwGoogleSignInButton` is the button a person signs in with: on the web it is the one Google
  draws (`google_sign_in_web` `renderButton`), the only way a web sign-in starts; elsewhere it is the app's own
  (`builder`) or a plain outlined button. `DwGoogleAuth.signInCommands({registration, introduce})` turns every
  sign-in Google reports into the same `DwSignInWithProvider` `signInCommand` makes, so one listener serves every
  platform (#680).

## 0.5.0

- Targets DartWay 0.24

## 0.4.0

- Targets DartWay 0.23

## 0.3.0

- Targets DartWay 0.22.

## 0.2.0

- Targets `dartway_auth_providers_shared` `^0.2.0` (DartWay 0.21).

- **Breaking:** `dw.signInWithGoogle()` (the `DwGoogleSignInCall` extension) is replaced by
  `DwGoogleAuth.signInCommand({registration, introduce})`, which runs the Google flow and answers the
  `DwSignInWithProvider` it makes without sending it. The app sends it with `dw.command` and calls
  `dw.signIn` on success, as with a code; a sign-up the project refuses (`consentsRequired`) is
  finished by sending `withRegistration(...)` of the same command, without asking Google again
  (dartway/dartway#374, D-137). Migration note `2026-10-09-provider-sign-in-command.md`.
- No longer depends on `dartway_core_flutter`.

## 0.1.0

- First version: the app's half of Sign in with Google (D-074). See
  `docs/4-server/auth-identity.md`.
