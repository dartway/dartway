import 'dart:async';
import 'dart:convert';

import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:dartway_push_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);
const bob = DwAuthSession(id: 8, token: 'token-8', isNewAccount: false);

final class NewsAlert extends DwDataObject {
  const NewsAlert({required this.id});

  @override
  final int id;

  @override
  String get dwTypeName => 'NewsAlert';

  @override
  Map<String, Object?> toJson() => {'id': id};

  static NewsAlert fromJson(Map<String, Object?> json) =>
      NewsAlert(id: json['id']! as int);

  @override
  bool operator ==(Object other) => other is NewsAlert && other.id == id;

  @override
  int get hashCode => id;
}

final protocol = DwWireProtocol([
  ...dwPushProtocolEntries,
  const DwProtocolEntry<NewsAlert>('NewsAlert', NewsAlert.fromJson),
], include: DwWireProtocol.core);

final class World {
  World() {
    server
      ..registerToken(alice.token, alice.id)
      ..registerToken(bob.token, bob.id)
      ..onCommand<DwRegisterPushToken>((command, call) {
        if (call.accountId == null) return const DwNotAuthenticated<void>();
        registrations.add((call.accountId!, command));
        return answer;
      })
      ..onCommand<DwUnregisterPushToken>((command, call) {
        unregistrations.add((call.accountId!, command.token));
        return const DwCallOk<void>(null);
      });
  }

  final server = DwFakeServer(protocol: protocol);
  final registrations = <(int, DwRegisterPushToken)>[];
  final unregistrations = <(int, String)>[];
  DwCallResult<void> answer = const DwCallOk<void>(null);
  final reports = <DwErrorReport>[];

  Future<DwFlutterCore> start(
    DwPush push, {
    DwAuthSession? session,
    DwWireProtocol? appProtocol,
  }) async {
    final core = DwFlutterCore(
      config: DwFlutterConfig(
        appVersion: '1.0.0+1',
        refusalText: (refusal) => refusal.code,
        onErrorReport: reports.add,
      ),
      protocol: appProtocol ?? protocol,
      baseUrl: server.baseUrl,
      httpTransport: server.httpTransport,
      liveConnector: server.liveConnector,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: dwFakeClientOptions,
      plugins: [push],
    );
    addTearDown(core.dispose);
    await core.init();
    await settle();
    return core;
  }
}

/// A transport whose named calls never answer — the iOS simulator, or a
/// bundle id that differs from `GoogleService-Info.plist` (#294).
final class SilentTransport extends DwPushTransportClient {
  SilentTransport(this.silent);

  final Set<String> silent;

  Future<T> _call<T>(String name, T answer) =>
      silent.contains(name) ? Completer<T>().future : Future.value(answer);

  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<bool> isAvailable() => _call('isAvailable', true);

  @override
  Future<DwPushPermission> permission() =>
      _call('permission', DwPushPermission.granted);

  @override
  Future<DwPushPermission> requestPermission() =>
      _call('requestPermission', DwPushPermission.granted);

  @override
  Future<void> attach(DwPushTransportEvents events) => _call('attach', null);

  @override
  Future<void> detach() async {}

  @override
  Future<String?> token() => _call('token', 'device-silent');

  @override
  Future<Map<Object?, Object?>?> takeInitialOpen() =>
      _call('takeInitialOpen', null);
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  late World world;
  setUp(() => world = World());

  group('registration', () {
    test('waits for a sign-in, then registers the token once', () async {
      final transport = DwFakePushTransport(issuedToken: 'device-1');
      final push = DwPush(
        transports: [transport],
        platform: DwPushPlatform.android,
      );
      final core = await world.start(push);
      expect(world.registrations, isEmpty, reason: 'nobody to register for');
      expect(push.token, 'device-1');

      await core.signIn(alice);
      await settle();
      expect(world.registrations, [
        (
          alice.id,
          const DwRegisterPushToken(
            transport: DwPushTransport.fcm,
            token: 'device-1',
            platform: DwPushPlatform.android,
          ),
        ),
      ]);

      // The same token again, from the SDK's refresh callback: nothing to do.
      transport.refreshToken('device-1');
      await settle();
      expect(world.registrations, hasLength(1));
    });

    test('a signed-in start registers once', () async {
      final push = DwPush(
        transports: [DwFakePushTransport(issuedToken: 'device-2')],
      );
      await world.start(push, session: alice);
      expect(world.registrations.map((r) => (r.$1, r.$2.token)), [
        (alice.id, 'device-2'),
      ]);
    });

    test('a refreshed token is registered again', () async {
      final transport = DwFakePushTransport(issuedToken: 'device-3');
      await world.start(DwPush(transports: [transport]), session: alice);
      transport.refreshToken('device-3b');
      await settle();
      expect(world.registrations.map((r) => r.$2.token), [
        'device-3',
        'device-3b',
      ]);
    });

    test('an account switch registers the token for the new account', () async {
      final core = await world.start(
        DwPush(transports: [DwFakePushTransport(issuedToken: 'device-4')]),
        session: alice,
      );
      await core.signIn(bob);
      await settle();
      expect(world.registrations.map((r) => (r.$1, r.$2.token)), [
        (alice.id, 'device-4'),
        (bob.id, 'device-4'),
      ]);
    });

    test(
      'a sign-out calls nothing; signing in again registers again',
      () async {
        final core = await world.start(
          DwPush(transports: [DwFakePushTransport(issuedToken: 'device-5')]),
          session: alice,
        );
        await core.signOut();
        await settle();
        expect(world.registrations, hasLength(1));
        expect(
          world.unregistrations,
          isEmpty,
          reason: 'the server stops sending when the key is revoked',
        );
        // A new sign-in of the same account: a new key to bind the device to.
        const again = DwAuthSession(
          id: 7,
          token: 'token-7b',
          isNewAccount: false,
        );
        world.server.registerToken(again.token, again.id);
        await core.signIn(again);
        await settle();
        expect(world.registrations.map((r) => (r.$1, r.$2.token)), [
          (alice.id, 'device-5'),
          (alice.id, 'device-5'),
        ]);
      },
    );

    test('a token issued after permission is granted is registered', () async {
      final transport = DwFakePushTransport(
        issuedToken: 'device-6',
        granted: false,
      );
      final push = DwPush(transports: [transport]);
      await world.start(push, session: alice);
      expect(world.registrations, isEmpty);
      expect(await push.requestPermission(), DwPushPermission.granted);
      await settle();
      expect(world.registrations.single.$2.token, 'device-6');
    });

    test(
      'a refused registration is reported and retried on the next nudge',
      () async {
        world.answer = DwCallRefused<void>(
          DwCallRefusal(DwPushRefusal.tokenInvalid, field: 'token'),
        );
        final transport = DwFakePushTransport(issuedToken: 'device-7');
        await world.start(DwPush(transports: [transport]), session: alice);
        expect(
          world.reports.map((r) => '${r.error}'),
          contains(contains('dw.pushTokenInvalid')),
        );
        world.answer = const DwCallOk<void>(null);
        transport.refreshToken('device-7b');
        await settle();
        expect(world.registrations.map((r) => r.$2.token), [
          'device-7',
          'device-7b',
        ]);
      },
    );

    test('pause unregisters and stops registering until resumed', () async {
      final transport = DwFakePushTransport(issuedToken: 'device-8');
      final push = DwPush(transports: [transport]);
      await world.start(push, session: alice);
      await push.pause();
      expect(world.unregistrations, [(alice.id, 'device-8')]);
      transport.refreshToken('device-8b');
      await settle();
      expect(world.registrations, hasLength(1));
      await push.resume();
      await settle();
      expect(world.registrations.last.$2.token, 'device-8b');
    });

    test('an app that keeps push off starts paused', () async {
      await world.start(
        DwPush(
          transports: [DwFakePushTransport(issuedToken: 'device-9')],
          isEnabled: () async => false,
        ),
        session: alice,
      );
      expect(world.registrations, isEmpty);
    });
  });

  test('a resume while the stored choice is still being read stands', () async {
    final stored = Completer<bool>();
    final push = DwPush(
      transports: [DwFakePushTransport(issuedToken: 'device-12')],
      isEnabled: () => stored.future,
    );
    await world.start(push, session: alice);
    await push.resume();
    stored.complete(false);
    await settle();
    expect(world.registrations.single.$2.token, 'device-12');
  });

  group('setup', () {
    test('picks the first transport the platform and device can run', () async {
      final rustore = DwFakePushTransport(
        transport: DwPushTransport.rustore,
        available: false,
      );
      final unsupported = DwFakePushTransport(supported: false);
      final fcm = DwFakePushTransport(issuedToken: 'device-10');
      final push = DwPush(transports: [unsupported, rustore, fcm]);
      await world.start(push, session: alice);
      expect(push.transport, same(fcm));
      expect(
        [unsupported.attachCount, rustore.attachCount, fcm.attachCount],
        [0, 0, 1],
      );
      expect(world.registrations.single.$2.transport, DwPushTransport.fcm);
    });

    test('is built before any core exists and reads nothing global', () async {
      // The plugin is an argument of the core's constructor: built first.
      final push = DwPush(
        transports: [DwFakePushTransport(issuedToken: 'device-11')],
      );
      await world.start(push, session: alice);
      expect(world.registrations, hasLength(1));
    });

    test(
      'a protocol without the push calls fails its start, and says why',
      () async {
        final push = DwPush(
          transports: [DwFakePushTransport(issuedToken: 'x')],
        );
        await world.start(push, appProtocol: DwWireProtocol.core);
        expect(
          world.reports.map((r) => '${r.error}'),
          contains(contains('dwPushProtocolEntries')),
        );
      },
    );
  });

  group('a platform that does not answer', () {
    for (final call in [
      'isAvailable',
      'attach',
      'permission',
      'token',
      'takeInitialOpen',
    ]) {
      test('$call is not waited for by the start, and is reported', () async {
        final push = DwPush(
          transports: [
            SilentTransport({call}),
          ],
          reportUnansweredAfter: const Duration(milliseconds: 50),
        );
        // Returns at all: before #294 a silent call kept `dw.init` waiting.
        await world.start(push);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          world.reports.map((r) => '${r.error}'),
          contains(contains('$call did not answer')),
        );
      });
    }

    test('a silent takeInitialOpen does not hold up the token', () async {
      await world.start(
        DwPush(
          transports: [
            SilentTransport({'takeInitialOpen'}),
          ],
        ),
        session: alice,
      );
      expect(world.registrations.single.$2.token, 'device-silent');
    });
  });

  group('opened notifications', () {
    Map<Object?, Object?> data({int id = 12, String? link = '/news/12'}) => {
      ...DwPushData(
        payload: NewsAlert(id: id),
        link: link,
      ).toWire(),
    };

    test('carry the typed payload and link', () async {
      final transport = DwFakePushTransport();
      final push = DwPush(transports: [transport]);
      await world.start(push);
      final opened = <DwPushOpened>[];
      push.opened.listen(opened.add);
      transport.openRaw(data());
      await settle();
      expect(opened.single.source, DwPushOpenSource.background);
      expect(opened.single.payloadAs<NewsAlert>(), const NewsAlert(id: 12));
      expect(opened.single.link, '/news/12');
    });

    test('the one that started the app waits for the first listener', () async {
      final push = DwPush(
        transports: [DwFakePushTransport(initialOpen: data(id: 5, link: null))],
      );
      await world.start(push);
      await settle();
      final opened = <DwPushOpened>[];
      push.opened.listen(opened.add);
      await settle();
      expect(opened.single.source, DwPushOpenSource.coldStart);
      expect(opened.single.payload, const NewsAlert(id: 5));
      expect(opened.single.link, isNull);
    });

    test('a payload this build cannot read is reported and the link still '
        'opens', () async {
      final transport = DwFakePushTransport();
      final push = DwPush(transports: [transport]);
      await world.start(push);
      final opened = <DwPushOpened>[];
      push.opened.listen(opened.add);
      transport.openRaw({
        'dw_type': 'FromANewerServer',
        'dw_payload': jsonEncode({'x': 1}),
        'dw_link': '/somewhere',
      }, source: DwPushOpenSource.webClick);
      await settle();
      expect(opened.single.payload, isNull);
      expect(opened.single.link, '/somewhere');
      expect(world.reports.single.error, isA<FormatException>());
    });

    test('foreground arrivals are reported with their text', () async {
      final transport = DwFakePushTransport();
      final push = DwPush(transports: [transport]);
      await world.start(push);
      final received = <DwPushReceived>[];
      push.received.listen(received.add);
      transport.receive({
        ...DwPushData(payload: const NewsAlert(id: 3)).toWire(),
        DwPushData.titleKey: 'Drawn by the device',
      });
      await settle();
      expect(received.single.title, 'Drawn by the device');
      expect(received.single.payloadAs<NewsAlert>(), const NewsAlert(id: 3));
    });
  });
}
