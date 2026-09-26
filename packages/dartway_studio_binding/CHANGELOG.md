# Changelog

## 0.2.1

- **Requires `dartway_router` 3.0.0** (#314), where a simple route's `extraPathSegment`
  replaces its name in the URL instead of doubling it. No behaviour change here: this
  package only reads `route.fullPath` and `descriptor.parent`, neither of which changed
  shape — the bump is the caret catching up with the workspace.

## 0.2.0

- **Requires `dartway_router` 2.0.0** (#288), where a zone guard takes the navigation target.
- **Signs in with `DwIdentifierKind.of`** (#283) instead of a copy of the rule of its own.
- **`DwStudioUser` compares by value.** The README builds it inside a `select`,
  which keeps what it produces only while it stays equal to the last one:
  without `==` every emission of the profile was a new person, and with it went
  a session report and a rescan of the feature tree.
- **The language the app reports is a tag** (`Locale.toLanguageTag()`), which is
  what the manifest lists. It used to be the bare language code — the same
  string for `en` and `ru`, and not for the first `zh-Hans`, where Studio's
  switcher would ask for a language the app does not have.

## 0.2.0-dev.1

- **Ported to DartWay 1.0.** `dartway_core_flutter` instead of the Serverpod core; `DwFeatureWidget`, `DwAppRouter`, `DwFlutterConfig` after the two-word renames (D-058). `DwStudioBinding` is no longer generic over a profile class: who is signed in comes from the project's own provider (`user:`), mapped to `DwStudioUser`. The persona switch runs 1.0's sign-in by code — `DwRequestCode` then `DwVerifyCode` with the code Studio holds, accepted by the server's `DwAuthConfig.fixedCode` — and signs out through `dw.signOut()`. The package was dropped from the tree by the 1.0 rewrite (`fce088f`) and is back.
