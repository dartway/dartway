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

  test('a malformed contract version is a malformed call, and a protocol '
      'error on the socket — as the real server answers it', () async {
    final server = DwFakeServer(
      protocol: DwWireProtocol(
        const [],
        include: roomsProtocol,
        contractVersion: '0.3.0',
      ),
    );
    final reply = await server.httpTransport.post(
      DwHttpPost(
        url: server.baseUrl.replace(path: DwHttpContract.callPath('ListRooms')),
        headers: {
          DwHttpContract.protocolHeader: '$dwProtocolVersion',
          DwHttpContract.appVersionHeader: '1.0.0+1',
          DwHttpContract.contractVersionHeader: 'five',
          DwHttpContract.contentTypeHeader: DwHttpContract.jsonContentType,
        },
        body: '{}',
      ),
    );
    expect(reply.status, 400);

    final socket = await server.liveConnector.connect(
      server.baseUrl.replace(
        scheme: 'ws',
        path: DwHttpContract.livePath,
        queryParameters: {
          DwHttpContract.liveProtocolParameter: '$dwProtocolVersion',
          DwHttpContract.liveContractVersionParameter: 'five',
        },
      ),
    );
    await socket.messages.drain<void>();
    expect(socket.closeCode, DwCloseCode.protocolError);
    expect(socket.closeReason, 'dw.protocol');
  });
}
