import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);

enum ShopEvent with DwAnalyticsEvent { productViewed, orderPlaced }

final protocol = DwWireProtocol(
  dwAnalyticsProtocolEntries,
  include: DwWireProtocol.core,
);

final class World {
  World() {
    server
      ..registerToken(alice.token, alice.id)
      ..onCommand<DwTrackEvents>((command, call) {
        final result = answer;
        if (result is DwCallOk<void>) batches.add((call.accountId, command));
        return result;
      });
  }

  final server = DwFakeServer(protocol: protocol);
  final batches = <(int?, DwTrackEvents)>[];
  DwCallResult<void> answer = const DwCallOk<void>(null);
  final reports = <DwErrorReport>[];

  List<String> get sentNames => [
    for (final (_, batch) in batches) ...batch.events.map((e) => e.name),
  ];

  Future<(DwFlutterCore, DwAnalytics)> start({
    DwAnalyticsStore? store,
    DwAuthSession? session,
    DwWireProtocol? appProtocol,
    Future<Map<String, Object?>> Function()? attribution,
    int batchSize = 50,
  }) async {
    final analytics = DwAnalytics(
      store: store ?? DwMemoryAnalyticsStore(),
      attribution: attribution,
      platform: DwAnalyticsPlatform.ios,
      batchSize: batchSize,
      flushInterval: const Duration(hours: 1),
    );
    final core = DwFlutterCore(
      config: DwFlutterConfig(
        appVersion: '2.1.0+40',
        refusalText: (refusal) => refusal.code,
        onErrorReport: reports.add,
      ),
      protocol: appProtocol ?? protocol,
      baseUrl: server.baseUrl,
      httpTransport: server.httpTransport,
      liveConnector: server.liveConnector,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: dwFakeClientOptions,
      plugins: [analytics],
    );
    addTearDown(() async {
      await analytics.dispose();
      await core.dispose();
    });
    await core.init();
    await settle();
    return (core, analytics);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late World world;
  setUp(() => world = World());

  test(
    'the opening is sent with its attribution, install id and build',
    () async {
      final (_, analytics) = await world.start(
        attribution: () async => {'utmSource': 'telegram'},
      );
      final (account, batch) = world.batches.single;
      expect(account, isNull);
      expect(batch.installId, analytics.installId);
      expect(batch.installId, hasLength(32));
      expect(batch.platform, DwAnalyticsPlatform.ios);
      expect(batch.appVersion, '2.1.0+40');
      expect(batch.events.single.name, 'dw.appOpened');
      expect(batch.events.single.properties, {'utmSource': 'telegram'});
      expect(analytics.pending, isEmpty);
    },
  );

  test('events wait and go in one call, numbered in order', () async {
    final (_, analytics) = await world.start();
    world.batches.clear();
    analytics
      ..track(ShopEvent.productViewed, {'productId': 12})
      ..track(ShopEvent.productViewed, {'productId': 13})
      ..track(ShopEvent.orderPlaced);
    await settle();
    expect(world.batches, isEmpty, reason: 'nothing is sent per event');

    await analytics.flush();
    final events = world.batches.single.$2.events;
    expect(events.map((e) => e.name), [
      'productViewed',
      'productViewed',
      'orderPlaced',
    ]);
    expect(events.map((e) => e.sequence), [2, 3, 4]);
    expect(events.first.properties, {'productId': 12});
  });

  test('a full batch is sent without waiting for the interval', () async {
    final (_, analytics) = await world.start(batchSize: 3);
    world.batches.clear();
    analytics
      ..track(ShopEvent.productViewed)
      ..track(ShopEvent.productViewed)
      ..track(ShopEvent.productViewed);
    await settle();
    expect(world.sentNames, hasLength(3));
  });

  test('a failed send keeps the events for the next one; a refused batch is '
      'dropped and reported', () async {
    final (_, analytics) = await world.start();
    world.batches.clear();
    world.answer = const DwCallFailed<void>('incident-1');
    analytics.track(ShopEvent.orderPlaced);
    await analytics.flush();
    expect(analytics.pending, hasLength(1));

    world.answer = const DwCallOk<void>(null);
    await analytics.flush();
    expect(world.sentNames, ['orderPlaced']);
    expect(analytics.pending, isEmpty);

    world.answer = DwCallRefused<void>(
      DwCallRefusal(DwAnalyticsRefusal.batchInvalid, field: 'events'),
    );
    analytics.track(ShopEvent.productViewed);
    await analytics.flush();
    expect(analytics.pending, isEmpty);
    expect(
      world.reports.map((r) => '${r.error}'),
      contains(contains('dw.analyticsBatchInvalid')),
    );
  });

  test('unsent events and the install id survive a restart, and numbering '
      'goes on', () async {
    final store = DwMemoryAnalyticsStore();
    world.answer = const DwCallFailed<void>('offline');
    final (core, analytics) = await world.start(store: store);
    analytics.track(ShopEvent.orderPlaced);
    await analytics.persisted;
    final installId = analytics.installId;
    await analytics.dispose();
    await core.dispose();

    world.answer = const DwCallOk<void>(null);
    final (_, again) = await world.start(store: store);
    expect(again.installId, installId);
    expect(world.sentNames, ['dw.appOpened', 'orderPlaced', 'dw.appOpened']);
    expect(world.batches.expand((b) => b.$2.events).map((e) => e.sequence), [
      1,
      2,
      3,
    ]);
  });

  test('a sign-in sends what waited and records the change', () async {
    final (core, analytics) = await world.start();
    world.batches.clear();
    analytics.track(ShopEvent.productViewed);
    await core.signIn(alice);
    await settle();
    await analytics.flush();
    expect(world.batches.first.$2.events.map((e) => e.name), ['productViewed']);
    expect(world.sentNames, ['productViewed', 'dw.accountChanged']);
    expect(world.batches.last.$1, alice.id);
  });

  test('going to the background records it and sends at once', () async {
    final (_, analytics) = await world.start();
    world.batches.clear();
    analytics.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    expect(world.sentNames, ['dw.appBackgrounded']);
  });

  test(
    'properties the store does not take are reported and not queued',
    () async {
      final (_, analytics) = await world.start();
      analytics.track(ShopEvent.orderPlaced, {
        'items': const [1, 2],
      });
      expect(analytics.pending, isEmpty);
      expect(world.reports, isNotEmpty);
    },
  );

  test('a protocol without DwTrackEvents is reported at init, and the app '
      'starts', () async {
    await world.start(appProtocol: DwWireProtocol.core);
    expect(
      world.reports.map((r) => '${r.error}'),
      contains(contains('dwAnalyticsProtocolEntries')),
    );
  });
}
