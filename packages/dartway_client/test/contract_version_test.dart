import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The client tells the server which contract it was compiled with, and a
/// server that moved to a newer breaking line answers it with the update
/// screen (#296).
void main() {
  test('calls carry the contract version; a newer server line is '
      'update-required', () async {
    final server =
        DwFakeServer(
            protocol: DwWireProtocol(
              const [],
              include: roomsProtocol,
              contractVersion: '0.3.0',
            ),
          )
          ..registerToken(alice.token, alice.id)
          ..onRequest<ListRooms>(
            (request, call) => const DwCallOk(<RoomView>[]),
          );
    final client = server.newClient(tokenStore: DwMemoryTokenStore(alice));
    addTearDown(client.stop);
    await client.start();

    expect((await client.fetch(const ListRooms())).isOk, isTrue);
    expect(server.calls.single.headers['dw-contract-version'], '0.3.0');

    server.contractVersion = '0.4.0';
    await client.fetch(const ListRooms());
    expect(server.calls.last.status, 426);
    expect(client.incompatibility, DwCallRefusal(DwCoreRefusal.updateRequired));
  });
}
