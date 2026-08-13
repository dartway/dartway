import 'dart:async';

import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Studio, as far as the app can tell. Everything Studio says crosses the wire
/// first — encoded and decoded exactly as the real channel would — so a message
/// that only works because the test handed the object over cannot pass here.
class _FakeStudio implements StudioMessageChannel {
  final _incoming = StreamController<StudioBridgeMessage>.broadcast();
  final heard = <StudioBridgeMessage>[];
  bool disposed = false;

  @override
  Stream<StudioBridgeMessage> get messages => _incoming.stream;

  @override
  void send(StudioBridgeMessage message) => heard.add(message);

  @override
  void dispose() {
    disposed = true;
    _incoming.close();
  }

  void say(StudioBridgeMessage message) {
    final decoded = StudioBridgeMessage.tryDecode(message.encode());
    expect(decoded, isNotNull);
    _incoming.add(decoded!);
  }

  Iterable<T> of<T extends StudioBridgeMessage>() => heard.whereType<T>();
}

class _RecordingDelegate implements StudioBridgeHostDelegate {
  final done = <String>[];

  @override
  void onNavigateRequest(String path) => done.add('navigate:$path');

  @override
  Future<void> onSignInRequest(String identifier, String secret) async =>
      done.add('signIn:$identifier:$secret');

  @override
  Future<void> onSignOutRequest() async => done.add('signOut');

  @override
  void onLocaleRequest(String locale) => done.add('locale:$locale');
}

const _manifest = StudioProjectManifest(
  projectName: 'Demo',
  zones: [
    StudioZoneSpec(
      label: 'Client app',
      rootPath: '/schedule',
      access: StudioZoneAccess.signedIn,
      screens: [
        StudioScreenSpec(
          path: '/schedule',
          title: 'Schedule',
          purpose: 'The week ahead',
        ),
      ],
    ),
  ],
);

/// Accepts one token and nothing else, so the tests are about the gate rather
/// than about signatures — those have a file of their own.
Future<bool> _acceptsOnly(String accessToken) async => accessToken == 'good';

void main() {
  late _FakeStudio studio;
  late _RecordingDelegate delegate;

  StudioBridgeHost attach({
    List<StudioFeatureInfo> features = const [],
    StudioInspectPoint? inspectPoint,
  }) {
    final host = StudioBridgeHost.attach(
      manifest: _manifest,
      delegate: delegate,
      currentPath: () => '/schedule',
      currentSession: () => const StudioSessionState(
        isSignedIn: true,
        userIdentifier: '79990000002',
      ),
      currentFeatures: () => features,
      currentLocale: () => 'ru',
      validateAccessToken: _acceptsOnly,
      inspectPoint: inspectPoint,
      channel: studio,
    );
    expect(host, isNotNull, reason: 'attach refused an explicit channel');
    return host!;
  }

  Future<void> connect() async {
    studio.say(const StudioConnectMessage(accessToken: 'good'));
    await pumpEventQueue();
  }

  setUp(() {
    studio = _FakeStudio();
    delegate = _RecordingDelegate();
  });

  test('the app announces itself the moment it attaches', () {
    attach();
    expect(studio.heard, [isA<AppReadyMessage>()]);
  });

  test('an accepted token is answered with the manifest', () async {
    final host = attach(
      features: const [StudioFeatureInfo(id: 'schedule/list', title: 'List')],
    );
    await connect();

    final answer = studio.of<ManifestMessage>().single;
    expect(answer.manifest.projectName, 'Demo');
    expect(answer.currentPath, '/schedule');
    expect(answer.session.userIdentifier, '79990000002');
    expect(answer.currentLocale, 'ru');
    expect(answer.features.single.id, 'schedule/list');
    expect(host.isConnected, isTrue);
  });

  test('a refused token is answered with silence', () async {
    final host = attach();
    studio.say(const StudioConnectMessage(accessToken: 'forged'));
    await pumpEventQueue();

    expect(studio.of<ManifestMessage>(), isEmpty);
    expect(host.isConnected, isFalse);
  });

  group('the gate covers every command, not just the manifest', () {
    test('an embedding page that presented nothing cannot drive the app',
        () async {
      final host = attach();

      studio.say(const NavigateRequestMessage('/admin'));
      studio.say(const SignInRequestMessage(
        identifier: '79990000002',
        secret: '123456',
      ));
      studio.say(const SignOutRequestMessage());
      studio.say(const LocaleRequestMessage('en'));
      await pumpEventQueue();

      expect(delegate.done, isEmpty);
      expect(host.isConnected, isFalse);
    });

    test('nor read what is declared on the screen', () async {
      attach(
        inspectPoint: (_, _) =>
            const StudioFeatureInfo(id: 'schedule/list', title: 'List'),
      );

      studio.say(const InspectPointRequestMessage(
        requestId: 'inspect-1',
        horizontalFraction: 0.5,
        verticalFraction: 0.5,
      ));
      await pumpEventQueue();

      expect(studio.of<InspectPointResultMessage>(), isEmpty);
    });

    test('a refused Studio stays refused for the commands that follow',
        () async {
      attach();
      studio.say(const StudioConnectMessage(accessToken: 'forged'));
      await pumpEventQueue();

      studio.say(const NavigateRequestMessage('/admin'));
      await pumpEventQueue();

      expect(delegate.done, isEmpty);
    });

    test('and every command lands once it has been let in', () async {
      attach(
        inspectPoint: (_, _) =>
            const StudioFeatureInfo(id: 'schedule/list', title: 'List'),
      );
      await connect();

      studio.say(const NavigateRequestMessage('/admin'));
      studio.say(const SignInRequestMessage(
        identifier: '79990000002',
        secret: '123456',
      ));
      studio.say(const SignOutRequestMessage());
      studio.say(const LocaleRequestMessage('en'));
      studio.say(const InspectPointRequestMessage(
        requestId: 'inspect-1',
        horizontalFraction: 0.5,
        verticalFraction: 0.5,
      ));
      await pumpEventQueue();

      expect(delegate.done, [
        'navigate:/admin',
        'signIn:79990000002:123456',
        'signOut',
        'locale:en',
      ]);
      final result = studio.of<InspectPointResultMessage>().single;
      expect(result.requestId, 'inspect-1');
      expect(result.feature?.id, 'schedule/list');
    });
  });

  group('reports', () {
    test('say nothing to a Studio that has not been let in', () async {
      final host = attach();

      host.reportRoute('/ad/123', routeName: 'adDetail');
      host.reportSession(StudioSessionState.signedOut);
      host.reportLocale('en');
      host.reportFeatures('/schedule', const [
        StudioFeatureInfo(
          id: 'schedule/list',
          title: 'List',
          knownIssues: ['the empty state is missing'],
        ),
      ]);
      await pumpEventQueue();

      expect(studio.heard, [isA<AppReadyMessage>()]);
    });

    test('reach a connected Studio', () async {
      final host = attach();
      await connect();

      host.reportRoute('/ad/123', routeName: 'adDetail');
      host.reportSession(StudioSessionState.signedOut);
      host.reportLocale('en');
      host.reportFeatures('/schedule', const [
        StudioFeatureInfo(id: 'schedule/list', title: 'List'),
      ]);

      expect(studio.of<RouteChangedMessage>().single.routeName, 'adDetail');
      expect(studio.of<SessionChangedMessage>().single.session.isSignedIn,
          isFalse);
      expect(studio.of<LocaleChangedMessage>().single.locale, 'en');
      expect(studio.of<FeaturesChangedMessage>().single.features.single.id,
          'schedule/list');
    });
  });

  test('detaching ends it', () async {
    final host = attach();
    await connect();

    host.detach();
    expect(studio.disposed, isTrue);
    expect(host.isConnected, isFalse);

    final before = studio.heard.length;
    host.reportRoute('/ad/123');
    await pumpEventQueue();
    expect(studio.heard, hasLength(before));
  });
}
