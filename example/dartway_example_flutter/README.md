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

The app reads this build's version from the platform with `PackageInfo.fromPlatform()`
in `lib/main.dart`. On web, that reads the `version.json` written by `flutter build web`.
`pubspec.yaml` keeps the marketing version; its `+1` is only a local-build fallback.
Release builds pass `--build-number=N` and use `--build-name` only to override the
marketing version. Studio's per-project counter will supply N (STD-E21); release
build numbers are not committed. Until that release flow is wired, the web image
uses pubspec's fallback build number.

`Dw-App-Version` labels sessions and decides nothing; the shared package's
contract version decides compatibility.

## Tests

    flutter test

Widget tests pump the whole app against `DwFakeServer` — an in-memory server
speaking the real HTTP contract and live socket — with a core built per test
(`test/support/app_test_app.dart`).
