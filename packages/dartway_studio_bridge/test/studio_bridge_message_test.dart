import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encodes a message, decodes the wire string back, and returns the result.
StudioBridgeMessage? _roundTrip(StudioBridgeMessage message) =>
    StudioBridgeMessage.tryDecode(message.encode());

void main() {
  const manifest = StudioProjectManifest(
    projectName: 'Demo',
    zones: [],
    personas: [
      StudioPersonaSpec(id: 'a', label: 'A', identifier: '1'),
    ],
  );

  group('round-trip every message type', () {
    test('appReady', () {
      expect(_roundTrip(const AppReadyMessage()), isA<AppReadyMessage>());
    });

    test('studioConnect', () {
      expect(
          _roundTrip(const StudioConnectMessage()), isA<StudioConnectMessage>());
    });

    test('signOutRequest', () {
      expect(_roundTrip(const SignOutRequestMessage()),
          isA<SignOutRequestMessage>());
    });

    test('navigateRequest carries the path', () {
      final decoded = _roundTrip(const NavigateRequestMessage('/schedule'));
      expect((decoded as NavigateRequestMessage).path, '/schedule');
    });

    test('personaRequest carries the id', () {
      final decoded = _roundTrip(const PersonaRequestMessage('coach-maria'));
      expect((decoded as PersonaRequestMessage).personaId, 'coach-maria');
    });

    test('routeChanged carries the path', () {
      final decoded = _roundTrip(const RouteChangedMessage('/auth'));
      expect((decoded as RouteChangedMessage).path, '/auth');
    });

    test('sessionChanged carries the session', () {
      final decoded = _roundTrip(
        const SessionChangedMessage(
          StudioSessionState(isSignedIn: true, activePersonaId: 'a'),
        ),
      );
      expect((decoded as SessionChangedMessage).session.activePersonaId, 'a');
    });

    test('manifest carries manifest, path and session', () {
      final decoded = _roundTrip(
        const ManifestMessage(
          manifest: manifest,
          currentPath: '/schedule',
          session: StudioSessionState.signedOut,
        ),
      );
      expect(decoded, isA<ManifestMessage>());
      final msg = decoded as ManifestMessage;
      expect(msg.manifest.projectName, 'Demo');
      expect(msg.manifest.personas.single.id, 'a');
      expect(msg.currentPath, '/schedule');
      expect(msg.session.isSignedIn, isFalse);
    });
  });

  group('tryDecode rejects foreign / malformed input', () {
    test('non-string data', () {
      expect(StudioBridgeMessage.tryDecode(42), isNull);
      expect(StudioBridgeMessage.tryDecode(null), isNull);
      expect(StudioBridgeMessage.tryDecode({'type': 'appReady'}), isNull);
    });

    test('invalid json string', () {
      expect(StudioBridgeMessage.tryDecode('not json'), isNull);
    });

    test('json that is not an object', () {
      expect(StudioBridgeMessage.tryDecode('[1,2,3]'), isNull);
      expect(StudioBridgeMessage.tryDecode('"hello"'), isNull);
    });

    test('missing or wrong envelope version', () {
      expect(StudioBridgeMessage.tryDecode('{"type":"appReady"}'), isNull);
      expect(
        StudioBridgeMessage.tryDecode(
            '{"dartwayStudioBridge":999,"type":"appReady"}'),
        isNull,
      );
    });

    test('unknown message type', () {
      expect(
        StudioBridgeMessage.tryDecode(
            '{"dartwayStudioBridge":1,"type":"bogus","payload":{}}'),
        isNull,
      );
    });

    test('a foreign postMessage object is ignored', () {
      // e.g. DWDS / browser-extension chatter on the same window.
      expect(
        StudioBridgeMessage.tryDecode('{"source":"react-devtools"}'),
        isNull,
      );
    });
  });

  test('encoded envelope carries the protocol version', () {
    expect(
      const AppReadyMessage().encode(),
      contains('"${StudioBridgeProtocol.envelopeKey}":'
          '${StudioBridgeProtocol.version}'),
    );
  });
}
