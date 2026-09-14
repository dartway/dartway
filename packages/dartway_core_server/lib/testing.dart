/// Starting a DartWay server inside tests: a throwaway database, a server on
/// a free port, raw HTTP calls and live sockets that speak the wire, and real
/// clients connected to it (`DwTestServer.connectClient`), and a provisioned
/// pair of file storage buckets (`DwTestStorage`).
library;

// The client, so an end-to-end test imports this library and the server's and
// nothing else. `DwNotAuthenticatedException` is left to the server library:
// both name one (the server's is thrown by `ctx.requireAccountId`), and a test
// importing both would find the name ambiguous.
export 'package:dartway_client/dartway_client.dart'
    hide DwNotAuthenticatedException;

export 'src/testing/dw_test_server.dart';
export 'src/testing/dw_test_storage.dart';
