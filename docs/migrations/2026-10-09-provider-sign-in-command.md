---
title: Google and Apple sign-in make a command the app sends itself
affects:
  dartway_auth_google: "0.2.0"
  dartway_auth_apple: "0.2.0"
---

## Who is affected

A project whose app calls `dw.signInWithGoogle(...)` or `dw.signInWithApple(...)`. Both extensions
are gone: `DwGoogleAuth.signInCommand(...)` and `DwAppleSignIn.signInCommand(...)` take the same
arguments (`registration`, `introduce`, and for Apple `scopes` and `webAuthenticationOptions`), run
the provider's flow and answer the `DwSignInWithProvider` — they send nothing. Neither package
depends on `dartway_core_flutter` any more.

## What to change

Replace each call with the command, sent and signed in as `DwVerifyCode` is:

```dart
// before
final result = await dw.signInWithGoogle(introduce: introduce);

// after
final signIn = await DwGoogleAuth.signInCommand(introduce: introduce);
final result = await dw.command(signIn);
if (result case DwCallOk(value: final session)) await dw.signIn(session);
```

The same for Apple with `DwAppleSignIn.signInCommand`. If the project's `onExternalAccountCreated`
refuses a sign-up (`consentsRequired`), keep `signIn` in the screen's state and, after the consent
step, send `signIn.withRegistration({...consents})` instead of running the provider again. A project
that built `DwSignInWithProvider` by hand to get there may switch to `signInCommand`; it does not have
to.

## How to check

`grep -rn "signInWithGoogle\|signInWithApple" <project>_flutter/lib` finds nothing, and the app
compiles.
