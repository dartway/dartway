# dartway_starter_flutter

The app, on `dartway_core_flutter`. How to run it against the server and in a
browser: `../README.md`.

- `lib/auth/` — signing in by phone or e-mail and code, the terms on sign-up
- `lib/app/` — the signed-in app: home, profile (photo, name, identifiers)
- `lib/admin/` — the admin panel: dashboard, members, user card, settings
- `lib/core/` — the DartWay core (`dw`), the router with the zones' shells,
  the profile gate, the refusal texts, the "update the app" screen, the
  section extension every screen renders its reads with
- `lib/shared/` — non-visual helpers several features use (extensions,
  formatters); the skeleton has none yet
- `lib/ui_kit/` — the design system, owned by this app: styles and every
  visual building block
- `lib/l10n/` — the texts (English and Russian); `flutter gen-l10n` writes
  `lib/l10n/gen/`

The app reads this build's version from the platform with `PackageInfo.fromPlatform()`
in `lib/main.dart`. On web, that reads the `version.json` written by `flutter build web`.
`pubspec.yaml` keeps the marketing version; its `+1` is only a local-build fallback.
Release builds pass `--build-number=N` and use `--build-name` only to override the
marketing version. Studio's per-project counter will supply N (STD-E21); release
build numbers are not committed. Until that release flow is wired, the web image
uses pubspec's fallback build number.

This label is sent as `Dw-App-Version` and decides nothing. Which builds the server
still serves is decided by the contract:
the `version:` of `dartway_starter_shared`, raised in a breaking line whenever a
change removes or renames anything an installed app sends or reads.

```bash
flutter test          # widget tests on the in-memory DwFakeServer
```
