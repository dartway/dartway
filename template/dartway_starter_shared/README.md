# dartway_starter_shared

The contract between the server and the app, in pure Dart: everything the two
exchange is declared here and nowhere else.

- `lib/src/profile.dart` · `admin.dart` · `settings.dart` — one file per
  feature of the server, named after its folder: data objects, requests and
  commands, with their field rules; `profile.dart` also holds `AuthIdentifier`,
  the one form a phone or an e-mail is stored in (applied by the app before it
  asks for a code and by the server's `normalize`), and the keys a sign-up
  sends with its code
- `lib/src/dartway_starter_channel.dart` — the live channels
- `lib/src/dartway_starter_refusal.dart` — the app's refusal codes (texts live
  in the app's catalogue)
- `lib/src/dartway_starter_upload.dart` — upload purposes and their limits
- `lib/src/dartway_starter_protocol.dart` — the protocol both sides speak: the
  generated one and the modules'
- `*.dw.dart`, `lib/generated/` — written by `dartway generate`; never edited

A rule written twice — once in the server, once in the app — drifts silently,
because each copy passes its own tests. Written here, it is one rule.

No Flutter, no database, no IO: whatever this package declares is compiled
into both sides.
