@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_client/dartway_client.dart';
import 'package:test/test.dart';

import 'fixtures/rooms.dart';

/// The WebSocket connector against a real socket: a minimal server that
/// answers one request kind, so the frames cross a real TCP connection.
/// Sends [frame] unless the socket is closing: a frame read during the closing
/// handshake gets no answer, as from any server.
void reply(WebSocket socket, String frame) {
  try {
    socket.add(frame);
  } on StateError {
    // Closing.
  }
}

void main() {
  test('a client over a real WebSocket fetches and reconnects', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((frame) {
        final message = DwClientMessage.fromJson(
          jsonDecode(frame as String) as Map<String, Object?>,
          roomsProtocol,
        );
        if (message is DwRequestMessage) {
          reply(
            socket,
            jsonEncode(
              DwResultMessage(
                id: message.id,
                status: DwResultStatus.ok,
                value: const ListRooms().encodeResult(const [
                  RoomView(id: 1, name: 'a'),
                ], roomsProtocol),
              ).toJson(roomsProtocol),
            ),
          );
        }
      });
    });
    addTearDown(() => server.close(force: true));

    final client = DwClient(
      protocol: roomsProtocol,
      endpoint: Uri.parse('ws://127.0.0.1:${server.port}/dw'),
      options: const DwClientOptions(reconnectDelay: Duration(milliseconds: 5)),
    );
    addTearDown(client.stop);
    await client.start();

    final first = await client.fetch(const ListRooms());
    expect(first.valueOrNull, const [RoomView(id: 1, name: 'a')]);

    await sockets.single.close();
    final second = await client.fetch(const ListRooms());
    expect(second.valueOrNull, const [RoomView(id: 1, name: 'a')]);
    expect(sockets, hasLength(2));
  });

  test(
    'an unreachable endpoint leaves the client retrying, not failing',
    () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final client = DwClient(
        protocol: roomsProtocol,
        endpoint: Uri.parse('ws://127.0.0.1:$port/dw'),
        options: const DwClientOptions(
          reconnectDelay: Duration(milliseconds: 5),
        ),
      );
      addTearDown(client.stop);
      await client.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.connectionStatus, isNot(DwConnectionStatus.connected));
    },
  );
}
