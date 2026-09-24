@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

enum _Upload with DwUploadPurpose { avatar }

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
            'protocol': '$dwProtocolVersion',
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
      expect(postHeaders.single.value('dw-protocol'), '$dwProtocolVersion');
      expect(postHeaders.single.value('dw-app-version'), '3.1.0+42');
      expect(
        postHeaders.single.value('authorization'),
        'Bearer ${alice.token}',
      );

      sockets.single.add(
        jsonEncode(
          DwUpdateMessage(
            channel: 'rooms',
            updates: DwChannelUpdates([c]),
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

  test('DwHttpStorageTransport: a storage host that accepts the connection '
      'and then answers nothing is retried at the stall timeout, not waited '
      "out for the ticket's life (#309, found in review)", () async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(alice.token, alice.id);
    final storage = DwFakeStorage(server);

    // Accepts the TCP connection and then says nothing: a path an OS has
    // not noticed is dead (a mobile network switch, a NAT mapping that
    // dropped) — unlike a closed port, which answers "connection refused"
    // at once.
    final silence = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => silence.close());
    final held = <Socket>[];
    final silenceSubscription = silence.listen(held.add);
    addTearDown(() async {
      await silenceSubscription.cancel();
      for (final socket in held) {
        socket.destroy();
      }
    });

    // The real transport, its first put redirected to the silent socket;
    // its body is 100 KB — comfortably inside an OS send buffer, so
    // `reportSent` fires for the whole thing in one go, the way review
    // found it does. The second put is the retry, going to the fake
    // storage as normal.
    var first = true;
    final http = DwHttpStorageTransport();
    addTearDown(http.close);
    final fallback = storage.transport;
    final transport = DwMemoryStorageTransport((put) {
      if (!first) return fallback.put(put);
      first = false;
      return http.put(
        DwStoragePut(
          url: Uri.parse('http://127.0.0.1:${silence.port}/x'),
          headers: put.headers,
          byteSize: put.byteSize,
          body: put.body,
          abort: put.abort,
          reportSent: put.reportSent,
        ),
      );
    });

    final client = server.newClient(
      tokenStore: DwMemoryTokenStore(alice),
      storageTransport: transport,
      options: const DwClientOptions(
        callTimeout: Duration(milliseconds: 200),
        retryDelay: Duration(milliseconds: 1),
        maxRetryDelay: Duration(milliseconds: 5),
        releaseDelay: Duration.zero,
        liveIdleDelay: Duration.zero,
      ),
    );
    addTearDown(client.stop);
    await client.start();

    final result = await client.files
        .upload(
          _Upload.avatar,
          DwUploadSource.bytes(Uint8List(100 * 1024)),
          fileName: 'a.png',
          contentType: 'image/png',
        )
        // Well under the ticket's 15-minute default life: a version of
        // this fix that let a body confirmed sent relax the watchdog to
        // the ticket's length, instead of the plain stall timeout, hung
        // here until then rather than retrying.
        .timeout(const Duration(seconds: 10));
    expect(result.isOk, isTrue);
    expect(storage.puts, 1, reason: 'the retry, once — not the first put');
  });
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
