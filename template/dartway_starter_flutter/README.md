# dartway_starter_flutter

The app, on `dartway_core_flutter`. How to run it against the server and in a
browser: `../README.md`.

- `lib/auth/` — signing in by phone or e-mail and code, the terms on sign-up
- `lib/app/` — the signed-in app: home, profile (photo, name, identifiers)
- `lib/admin/` — the admin panel: dashboard, members, user card, settings
- `lib/core/` — the DartWay core (`dw`), the router, the profile gate, the
  refusal texts, the "update the app" screen
- `lib/shared/` — building blocks several features use
- `lib/ui_kit/` — the design system, owned by this app
- `lib/l10n/` — the texts (English and Russian); `flutter gen-l10n` writes
  `lib/l10n/gen/`

`lib/app_version.dart` repeats the `version:` of `pubspec.yaml` (a test holds
them equal). Which builds the server still serves is decided by the contract:
the `version:` of `dartway_starter_shared`, raised in a breaking line whenever a
change removes or renames anything an installed app sends or reads.

```bash
flutter test          # widget tests on the in-memory DwFakeServer
```
