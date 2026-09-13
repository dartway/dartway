# dartway_example_flutter

The DartWay example app — a fitness club — on DartWay 1.0. It speaks to
`../dartway_example_server` over one WebSocket, in the DTOs declared in
`../dartway_example_shared`.

## Running

Start the server first (see `../dartway_example_server`), then:

    flutter run -d chrome

The app connects to `ws://localhost:8080/dw` (`ws://10.0.2.2:8080/dw` on the
Android emulator). Another address is compiled in:

    flutter run --dart-define=DW_BACKEND_URL=ws://localhost:18080/dw

With the development seed, the personas `+7 999 000-00-01` (admin), `…02`
(staff) and `…03` (client) sign in with the code `111111`.

## Tests

    flutter test

Widget tests pump the whole app against `DwFakeServer` — an in-memory server
speaking the real wire protocol — with a core built per test
(`test/support/example_test_app.dart`).
