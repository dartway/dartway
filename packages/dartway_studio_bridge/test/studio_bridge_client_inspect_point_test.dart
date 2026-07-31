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

/// The inspect requests the client put on the wire, in order.
extension on _FakeChannel {
  List<InspectPointRequestMessage> get inspectRequests =>
      sent.whereType<InspectPointRequestMessage>().toList();
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
        InspectPointResultMessage(
          requestId: channel.inspectRequests.single.requestId,
          feature: const StudioFeatureInfo(id: 'ad/card', title: 'Ad card'),
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

    // Without correlation this is the bug that bites in the real flow: tap a
    // spot the app is slow to answer, give up on it, tap elsewhere — and the
    // late answer to the first tap resolves the second, so Studio shows a
    // confidently wrong passport instead of nothing.
    test('drops a late answer to a request that already timed out', () async {
      final channel = _FakeChannel();
      final client = StudioBridgeClient(channel: channel)..start();

      final abandoned = await client.inspectPoint(
        0.1,
        0.1,
        timeout: const Duration(milliseconds: 20),
      );
      expect(abandoned, isNull);

      final current = client.inspectPoint(
        0.9,
        0.9,
        timeout: const Duration(milliseconds: 100),
      );
      channel.emit(
        InspectPointResultMessage(
          requestId: channel.inspectRequests.first.requestId,
          feature: const StudioFeatureInfo(id: 'stale', title: 'Stale'),
        ),
      );

      expect(await current, isNull);
      client.dispose();
    });

    test('gives two in-flight requests their own answers', () async {
      final channel = _FakeChannel();
      final client = StudioBridgeClient(channel: channel)..start();

      final first = client.inspectPoint(0.1, 0.1);
      final second = client.inspectPoint(0.9, 0.9);
      final requests = channel.inspectRequests;
      expect(requests, hasLength(2));
      expect(requests.first.requestId, isNot(requests.last.requestId));

      // Answered out of order, as a busy app may well do.
      channel.emit(
        InspectPointResultMessage(
          requestId: requests.last.requestId,
          feature: const StudioFeatureInfo(id: 'second', title: 'Second'),
        ),
      );
      channel.emit(
        InspectPointResultMessage(
          requestId: requests.first.requestId,
          feature: const StudioFeatureInfo(id: 'first', title: 'First'),
        ),
      );

      expect((await first)?.id, 'first');
      expect((await second)?.id, 'second');
      client.dispose();
    });

    // Closing the preview panel mid-inspect must not surface an error out of
    // a disposed client — the awaiting caller just learns nothing was found.
    test('resolves a pending request with null on dispose', () async {
      final channel = _FakeChannel();
      final client = StudioBridgeClient(channel: channel)..start();

      final pending = client.inspectPoint(0.5, 0.5);
      client.dispose();

      expect(await pending, isNull);
    });
  });
}
