# dartway_example_flutter

The DartWay example app — a fitness club — on DartWay 1.0. It calls
`../dartway_example_server` over HTTP and follows it live over one WebSocket,
in the DTOs declared in `../dartway_example_shared`.

## Running

Start the server first (see `../README.md`), then:

    flutter run

The app calls `http://localhost:8080` (`http://10.0.2.2:8080` on the Android
emulator). Another address is compiled in:

    flutter run --dart-define=DW_BACKEND_URL=http://localhost:18080

The build it reports (`lib/core/app_version.dart`) is the `version` of
`pubspec.yaml`; a test keeps the two equal.

## Tests

    flutter test

Widget tests pump the whole app against `DwFakeServer` — an in-memory server
speaking the real HTTP contract and live socket — with a core built per test
(`test/support/example_test_app.dart`).
