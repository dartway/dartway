# dartway_example_server

The DartWay example server — a fitness club — on `dartway_core_server`. How to
run it, seed it and test it: `../README.md`.

- `lib/src/entities/` — row classes (`…Row`), generated tables in `*.dw.dart`
- `lib/src/handlers/` — one handler per request and command
- `lib/src/example_context.dart` — the caller's profile and the access rules
- `lib/src/example_channels.dart` — who may listen to which channel
- `lib/src/migrations/` — migrations, written by `bin/migrate.dart create`
- `bin/server.dart` · `bin/migrate.dart` · `bin/seed_dev.dart`
