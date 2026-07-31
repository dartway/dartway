import 'dart:async';

import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory two-way pipe standing in for the real `postMessage`
/// transport: [sent] records what the client sent, and [emit] simulates a
/// message arriving from the app.
class _FakeChannel implements StudioMessageChannel {
  final sent = <StudioBridgeMessage>[];
  final _incoming = StreamController<StudioBridgeMessage>.broadcast();

  @override
  Stream<StudioBridgeMessage> get messages => _incoming.stream;

  @override
  void send(StudioBridgeMessage message) => sent.add(message);

  void emit(StudioBridgeMessage message) => _incoming.add(message);

  @override
  void dispose() => _incoming.close();
}

void main() {
  group('StudioBridgeClient.inspectPoint', () {
    test('sends the fractional point and resolves with the app\'s answer',
        () async {
      final channel = _FakeChannel();
      final client = StudioBridgeClient(channel: channel)..start();

      final result = client.inspectPoint(0.25, 0.5);
      expect(
        channel.sent,
        contains(
          isA<InspectPointRequestMessage>()
              .having(
                (message) => message.horizontalFraction,
                'horizontalFraction',
                0.25,
              )
              .having(
                (message) => message.verticalFraction,
                'verticalFraction',
                0.5,
              ),
        ),
      );

      channel.emit(
        const InspectPointResultMessage(
          StudioFeatureInfo(id: 'ad/card', title: 'Ad card'),
        ),
      );

      expect((await result)?.id, 'ad/card');
      client.dispose();
    });

    test('resolves with null when the app never answers', () async {
      final channel = _FakeChannel();
      final client = StudioBridgeClient(channel: channel)..start();

      // An app built against an older bridge doesn't know this message and
      // stays silent — the timeout must still resolve, not hang.
      final result = await client.inspectPoint(
        0.1,
        0.1,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
      client.dispose();
    });
  });
}
