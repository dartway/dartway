import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
// Not part of the public API: the guard both web channels share, and the one
// piece of them a VM test can reach at all.
import 'package:dartway_studio_bridge/src/transport/studio_message_drop_report.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// An envelope of ours at [version], carrying [type].
String _envelope(int version, String type) =>
    '{"dartwayStudioBridge":$version,"type":"$type","payload":{}}';

void main() {
  group('envelopeVersionOf', () {
    test('reads the version out of one of our envelopes', () {
      expect(
        StudioBridgeProtocol.envelopeVersionOf(
          const AppReadyMessage().encode(),
        ),
        StudioBridgeProtocol.version,
      );
    });

    test('reads a version we do not speak — the whole point', () {
      expect(
        StudioBridgeProtocol.envelopeVersionOf(_envelope(3, 'appReady')),
        3,
      );
    });

    test('null for somebody else JSON on the same window', () {
      expect(
        StudioBridgeProtocol.envelopeVersionOf('{"type":"webpackHotUpdate"}'),
        isNull,
      );
    });

    test('null for anything that is not JSON, or not a map', () {
      expect(StudioBridgeProtocol.envelopeVersionOf('not json at all'), isNull);
      expect(StudioBridgeProtocol.envelopeVersionOf('[1,2,3]'), isNull);
      expect(StudioBridgeProtocol.envelopeVersionOf(null), isNull);
      expect(StudioBridgeProtocol.envelopeVersionOf(42), isNull);
    });

    test('null when the marker is there but is not a version', () {
      expect(
        StudioBridgeProtocol.envelopeVersionOf('{"dartwayStudioBridge":"4"}'),
        isNull,
      );
    });

    test('takes an already-decoded map, so nobody parses twice', () {
      expect(
        StudioBridgeProtocol.envelopeVersionOf(const {
          'dartwayStudioBridge': 4,
        }),
        4,
      );
    });
  });

  group('StudioMessageDropReason.ofPayload', () {
    test('null for a message that decodes', () {
      expect(
        StudioMessageDropReason.ofPayload(const AppReadyMessage().encode()),
        isNull,
      );
    });

    test('a foreign message is not a repair', () {
      expect(
        StudioMessageDropReason.ofPayload('{"source":"react-devtools"}'),
        StudioMessageDropReason.notAnEnvelope,
      );
      expect(
        StudioMessageDropReason.ofPayload('ping'),
        StudioMessageDropReason.notAnEnvelope,
      );
    });

    test('an app on v3 talking to a Studio on v4 is a version mismatch', () {
      // The day-long handshake from issue #98: both sides speak the bridge and
      // neither hears the other. `tryDecode` cannot tell this from the line
      // above — it answers null to both.
      final wrongVersion = _envelope(
        StudioBridgeProtocol.version - 1,
        StudioBridgeProtocol.appReady,
      );
      expect(StudioBridgeMessage.tryDecode(wrongVersion), isNull);
      expect(
        StudioMessageDropReason.ofPayload(wrongVersion),
        StudioMessageDropReason.versionMismatch,
      );
      expect(
        StudioBridgeProtocol.envelopeVersionOf(wrongVersion),
        StudioBridgeProtocol.version - 1,
      );
    });

    test('our version, a type this build has not heard of', () {
      // How the protocol grows without cutting off the field: the other side is
      // newer, not broken. Reporting it as a version mismatch would send
      // somebody rebuilding for nothing.
      expect(
        StudioMessageDropReason.ofPayload(
          _envelope(StudioBridgeProtocol.version, 'somethingAddedLater'),
        ),
        StudioMessageDropReason.unknownType,
      );
    });
  });

  group('StudioMessageDrop', () {
    test('says what it knows and nothing it does not', () {
      expect(
        const StudioMessageDrop(
          StudioMessageDropReason.versionMismatch,
          origin: 'https://app.example',
          envelopeVersion: 3,
        ).toString(),
        'StudioMessageDrop(versionMismatch, origin: https://app.example, '
        'envelope: v3)',
      );
      expect(
        const StudioMessageDrop(
          StudioMessageDropReason.notAMessageEvent,
        ).toString(),
        'StudioMessageDrop(notAMessageEvent)',
      );
    });
  });

  group('reporting a drop', () {
    test('no observer, nothing happens', () {
      expect(
        () => reportStudioMessageDrop(
          null,
          const StudioMessageDrop(StudioMessageDropReason.notAnEnvelope),
        ),
        returnsNormally,
      );
    });

    test('the observer gets the drop', () {
      final seen = <StudioMessageDrop>[];
      reportStudioMessageDrop(
        seen.add,
        const StudioMessageDrop(
          StudioMessageDropReason.foreignSource,
          origin: 'https://app.example',
        ),
      );
      expect(seen.single.reason, StudioMessageDropReason.foreignSource);
      expect(seen.single.origin, 'https://app.example');
    });

    test('an observer that throws does not take the channel with it', () {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      expect(
        () => reportStudioMessageDrop(
          (_) => throw StateError('the diagnostic itself is broken'),
          const StudioMessageDrop(StudioMessageDropReason.versionMismatch),
        ),
        returnsNormally,
      );
      expect(errors.single.exception, isA<StateError>());
      expect(errors.single.library, 'dartway_studio_bridge');
    });
  });
}
