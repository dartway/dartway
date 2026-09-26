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

/// A transport whose `attach` completes only when the test releases it —
/// proving that an attach which finishes *after* `permissionDeadline` has
/// already been given up on is still used once it does.
final class LateAttachTransport extends DwPushTransportClient {
  LateAttachTransport({this.issuedToken, this.granted = true});

  final String? issuedToken;
  bool granted;

  final Completer<void> _gate = Completer<void>();

  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<void> attach(DwPushTransportEvents events) => _gate.future;

  @override
  Future<void> detach() async {}

  @override
  Future<DwPushPermission> permission() async =>
      granted ? DwPushPermission.granted : DwPushPermission.notDetermined;

  @override
  Future<DwPushPermission> requestPermission() async {
    granted = true;
    return DwPushPermission.granted;
  }

  @override
  Future<String?> token() async => granted ? issuedToken : null;

  /// Lets the gated `attach` complete.
  void releaseAttach() => _gate.complete();
}

/// A transport whose `attach` fails outright — proving that the framework
/// tells "the background start decided no transport can run here" apart
/// from "it has not decided anything yet".
final class ThrowingAttachTransport extends DwPushTransportClient {
  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<void> attach(DwPushTransportEvents events) async =>
      throw StateError('attach failed for good');

  @override
  Future<void> detach() async {}

  @override
  Future<DwPushPermission> permission() async => DwPushPermission.notDetermined;

  @override
  Future<DwPushPermission> requestPermission() async =>
      DwPushPermission.notDetermined;

  @override
  Future<String?> token() async => null;
}

/// A transport that attaches at once but whose `requestPermission` answers
/// only when the test says so — the system permission dialog, which may
/// take the user far longer than any technical deadline.
final class SlowDialogTransport extends DwPushTransportClient {
  SlowDialogTransport({this.issuedToken});

  final String? issuedToken;
  final Completer<DwPushPermission> _dialog = Completer();

  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<void> attach(DwPushTransportEvents events) async {}

  @override
  Future<void> detach() async {}

  @override
  Future<DwPushPermission> permission() async => DwPushPermission.notDetermined;

  @override
  Future<DwPushPermission> requestPermission() => _dialog.future;

  @override
  Future<String?> token() async => issuedToken;

  /// The user answered the system dialog.
  void answerDialog(DwPushPermission answer) => _dialog.complete(answer);
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

  group('requestPermission and permission answer on a deadline (#338)', () {
    // Bounded at 500 ms, well over permissionDeadline (50 ms) in most cases
    // below: without the deadline in DwPush.requestPermission/permission, a
    // transport whose attach never completes hangs `_attached.future`
    // forever, and this .timeout throws instead of the test ever seeing an
    // answer — the mutation this acceptance test is meant to catch.
    const testBound = Duration(milliseconds: 500);

    test(
      'requestPermission answers unanswered and reports the silence',
      () async {
        final push = DwPush(
          transports: [
            SilentTransport({'attach'}),
          ],
          reportUnansweredAfter: const Duration(milliseconds: 50),
          permissionDeadline: const Duration(milliseconds: 50),
        );
        await world.start(push);

        final answer = await push.requestPermission().timeout(testBound);

        expect(answer, DwPushPermission.unanswered);
        expect(
          world.reports.map((r) => '${r.error}'),
          contains(contains('attach did not answer')),
        );
      },
    );

    test(
      'permission answers unanswered the same way, on the same silence',
      () async {
        final push = DwPush(
          transports: [
            SilentTransport({'attach'}),
          ],
          permissionDeadline: const Duration(milliseconds: 50),
        );
        await world.start(push);

        final answer = await push.permission().timeout(testBound);

        expect(answer, DwPushPermission.unanswered);
      },
    );

    test('permission answers unanswered when the platform itself stays silent, '
        'even once attached', () async {
      final push = DwPush(
        transports: [
          SilentTransport({'permission'}),
        ],
        permissionDeadline: const Duration(milliseconds: 50),
      );
      await world.start(push);

      final answer = await push.permission().timeout(testBound);

      expect(answer, DwPushPermission.unanswered);
    });

    test(
      'a transport that attaches and answers normally is unaffected',
      () async {
        final transport = DwFakePushTransport(issuedToken: 'device-13');
        final push = DwPush(
          transports: [transport],
          permissionDeadline: const Duration(milliseconds: 50),
        );
        await world.start(push, session: alice);

        final answer = await push.requestPermission().timeout(testBound);

        expect(answer, DwPushPermission.granted);
        await settle();
        expect(world.registrations.single.$2.token, 'device-13');
      },
    );

    test('permissionDeadline is separate from reportUnansweredAfter: lowering '
        'the report threshold does not shorten the wait', () async {
      final push = DwPush(
        transports: [
          SilentTransport({'attach'}),
        ],
        reportUnansweredAfter: const Duration(milliseconds: 20),
        permissionDeadline: const Duration(milliseconds: 300),
      );
      await world.start(push);

      // The silence is reported well before permissionDeadline elapses…
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        world.reports.map((r) => '${r.error}'),
        contains(contains('attach did not answer')),
      );

      // …but requestPermission has not given up yet at that point.
      var settled = false;
      final answer = push.requestPermission().then((v) {
        settled = true;
        return v;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        settled,
        isFalse,
        reason: 'permissionDeadline (300 ms) has not passed yet',
      );

      expect(
        await answer.timeout(const Duration(seconds: 1)),
        DwPushPermission.unanswered,
      );
    });

    test('a late attach past permissionDeadline is still used: the token '
        'registers once permission is already granted, and a later '
        'requestPermission answers for real', () async {
      final transport = LateAttachTransport(issuedToken: 'device-late');
      final push = DwPush(
        transports: [transport],
        permissionDeadline: const Duration(milliseconds: 50),
      );
      await world.start(push, session: alice);

      final first = await push.requestPermission().timeout(testBound);
      expect(first, DwPushPermission.unanswered);
      expect(world.registrations, isEmpty);

      transport.releaseAttach();
      await settle();
      expect(world.registrations.single.$2.token, 'device-late');

      final second = await push.requestPermission().timeout(testBound);
      expect(second, DwPushPermission.granted);
    });

    test('a transport whose attach throws answers unsupported promptly, never '
        'unanswered', () async {
      final push = DwPush(
        transports: [ThrowingAttachTransport()],
        // Long on purpose: proves the answer does not wait for it — a
        // background start that has already decided "no transport here"
        // is not "still deciding".
        permissionDeadline: const Duration(seconds: 5),
      );
      await world.start(push);

      expect(
        await push.requestPermission().timeout(testBound),
        DwPushPermission.unsupported,
      );
      expect(
        await push.permission().timeout(testBound),
        DwPushPermission.unsupported,
      );
    });

    test(
      "requestPermission's own call to the platform is never bounded by "
      'permissionDeadline: a slow system dialog still answers for real',
      () async {
        final transport = SlowDialogTransport(issuedToken: 'device-dialog');
        final push = DwPush(
          transports: [transport],
          permissionDeadline: const Duration(milliseconds: 50),
        );
        await world.start(push, session: alice);
        await settle(); // attach is immediate here; let it complete first.

        final answer = push.requestPermission();
        // Outlive permissionDeadline with the dialog still open.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        transport.answerDialog(DwPushPermission.granted);

        expect(
          await answer.timeout(const Duration(seconds: 2)),
          DwPushPermission.granted,
        );
        await settle();
        expect(world.registrations.single.$2.token, 'device-dialog');
      },
    );
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
