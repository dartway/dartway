@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_client/dartway_client.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The default transports against real sockets: a minimal `dart:io` server
/// that answers one request over HTTP and serves the live socket, so bytes
/// cross a real TCP connection both ways.
void main() {
  test(
    'calls over HTTP and updates over a WebSocket, with a reconnect',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sockets = <WebSocket>[];
      final postHeaders = <HttpHeaders>[];
      var rooms = [a, b];

      server.listen((request) async {
        if (request.uri.path == '/dw/live') {
          expect(request.uri.queryParameters, {
            'protocol': '1',
            'app': '3.1.0+42',
          });
          final socket = await WebSocketTransformer.upgrade(request);
          sockets.add(socket);
          socket.add(jsonEncode(DwHelloMessage('c${sockets.length}').toJson()));
          socket.listen((frame) {
            final message = DwClientMessage.fromJson(
              jsonDecode(frame as String),
            );
            if (message is DwAuthenticateMessage) {
              socket.add(
                jsonEncode(DwAuthenticatedMessage.account(alice.id).toJson()),
              );
            } else if (message is DwSubscribeMessage) {
              socket.add(
                jsonEncode(DwSubscribedMessage(message.channel).toJson()),
              );
            }
          });
          return;
        }
        postHeaders.add(request.headers);
        final body = await utf8.decodeStream(request);
        expect(jsonDecode(body), const <String, Object?>{});
        final response = DwApiResponse.ok([for (final r in rooms) r.toJson()]);
        request.response
          ..statusCode = response.httpStatus
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(response.toJson()));
        await request.response.close();
      });

      final client = DwAppClient(
        protocol: roomsProtocol,
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        appVersion: '3.1.0+42',
        // Signed in: a socket is opened only for an account (D-020).
        tokenStore: DwMemoryTokenStore(alice),
        options: const DwClientOptions(
          retryDelay: Duration(milliseconds: 10),
          maxRetryDelay: Duration(milliseconds: 50),
          releaseDelay: Duration.zero,
        ),
      );
      addTearDown(client.stop);
      await client.start();

      final watch = client.watch(const _LiveRooms());
      await until(() => watch.isLive);
      expect(dataOf(watch.state), [a, b]);
      expect(postHeaders.single.value('dw-protocol'), '1');
      expect(postHeaders.single.value('dw-app-version'), '3.1.0+42');
      expect(
        postHeaders.single.value('authorization'),
        'Bearer ${alice.token}',
      );

      sockets.single.add(
        jsonEncode(
          DwUpdateMessage(
            channel: 'rooms',
            updates: DwUpdateTransport([c]),
          ).toJson(),
        ),
      );
      await until(() => dataOf(watch.state).length == 3);
      expect(dataOf(watch.state), [c, a, b]);

      rooms = [b];
      await sockets.single.close(DwCloseCode.serverStopping);
      await until(() => sockets.length == 2 && watch.isLive);
      await until(() => dataOf(watch.state).length == 1);
      expect(dataOf(watch.state), [b], reason: 're-run after the reconnect');
      expect(postHeaders, hasLength(2));
    },
  );
}

/// Rooms over the `rooms` channel, served by the test server above as the
/// `ListRoomsOffline` path would be.
final class _LiveRooms extends DwListRequest<RoomView> {
  const _LiveRooms();

  @override
  String get dwTypeName => 'ListRoomsOffline';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];

  @override
  bool operator ==(Object other) => other is _LiveRooms;

  @override
  int get hashCode => 0;
}
