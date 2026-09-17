import 'dart:io';

import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestAnswer, DwTestDatabase, DwTestServer;
import 'package:test/test.dart';

enum ShopEvent with DwAnalyticsEvent { catalogOpened, orderPlaced }

/// Records an order in a command: the server-side event, rolled back with
/// the command when [refuse].
final class PlaceOrder extends DwActionCommand<void> {
  const PlaceOrder({required this.total, this.refuse = false});

  final int total;
  final bool refuse;

  @override
  String get dwTypeName => 'PlaceOrder';

  @override
  Map<String, Object?> toJson() => {'total': total, 'refuse': refuse};

  static PlaceOrder fromJson(Map<String, Object?> json) =>
      PlaceOrder(total: json['total']! as int, refuse: json['refuse']! as bool);
}

final DwWireProtocol testProtocol = DwWireProtocol([
  ...dwAnalyticsProtocolEntries,
  const DwProtocolEntry<PlaceOrder>('PlaceOrder', PlaceOrder.fromJson),
], include: DwWireProtocol.core);

final DwCallHandler placeOrderHandler = DwCallHandler.command<PlaceOrder, void>(
  access: DwAccessRule.anonymous,
  handle: (ctx, command) async {
    await ctx.analytics.track(
      ShopEvent.orderPlaced,
      properties: {'total': command.total},
    );
    if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
  },
);

final class _SilentLogger implements DwServerLogger {
  const _SilentLogger();

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (Platform.environment['DW_TEST_LOG'] != null) {
      stderr.writeln(
        '${level.name} $message${error == null ? '' : ': $error'}',
      );
    }
  }

  @override
  DwServerLogger scoped(String scope) => this;
}

typedef TestAccount = ({int id, String token});

final class AnalyticsHarness {
  AnalyticsHarness._(this.database, this.server);

  final DwTestDatabase database;
  final DwTestServer server;

  static Future<AnalyticsHarness> start(DwAnalyticsSettings settings) async {
    final DwDatabaseConfig admin;
    try {
      admin = DwDatabaseConfig.fromEnvironment(Platform.environment);
    } on ArgumentError catch (error) {
      throw StateError(
        'The dartway_analytics_server suites need a Postgres server: set '
        'DW_DATABASE_HOST, _PORT, _NAME, _USER, _PASSWORD and _SSL. ($error)',
      );
    }
    final database = await DwTestDatabase.create(
      admin: admin,
      prefix: 'analytics_test',
    );
    try {
      final server = await DwTestServer.start(
        DwAppServer(
          protocol: testProtocol,
          migrations: const [],
          database: database.config,
          auth: DwAuthConfig(
            normalize: (kind, raw) => raw.trim().toLowerCase(),
            deliverCode: (ctx, kind, identifier, code) async {},
          ),
          handlers: [placeOrderHandler],
          modules: [DwAnalyticsModule(settings: settings)],
          logger: const _SilentLogger(),
          settings: const DwServerSettings(
            jobPollInterval: Duration(seconds: 30),
          ),
        ),
      );
      return AnalyticsHarness._(database, server);
    } catch (_) {
      await database.drop();
      rethrow;
    }
  }

  DwDatabaseHandle get db => server.db;

  int _accounts = 0;

  Future<TestAccount> account() async {
    final accounts = server.server.accounts;
    final ensured = await accounts.ensure(
      DwIdentifierKind.email,
      'member${++_accounts}-${DateTime.now().microsecondsSinceEpoch}@test',
    );
    final issued = await accounts.issueKey(ensured.accountId, label: 'test');
    return (id: ensured.accountId, token: issued.token);
  }

  Future<DwTestAnswer> send(
    DwServerCall<Object?> call, {
    TestAccount? as,
    String? key,
  }) async {
    final caller = server.caller(token: as?.token);
    try {
      return await caller.call(call, key: key);
    } finally {
      caller.close();
    }
  }

  Future<void> stop() async {
    await server.stop();
    await database.drop();
  }
}

AnalyticsHarness Function() useAnalyticsHarness({
  DwAnalyticsSettings settings = const DwAnalyticsSettings(),
}) {
  AnalyticsHarness? harness;
  setUpAll(() async => harness = await AnalyticsHarness.start(settings));
  tearDownAll(() async => harness?.stop());
  return () => harness!;
}

int _installs = 0;

/// A fresh install id for one test.
String newInstallId() =>
    'install-${DateTime.now().microsecondsSinceEpoch}-${++_installs}';

DwTrackedEvent event(
  String name,
  int sequence,
  DateTime at, [
  Map<String, Object?> properties = const {},
]) => DwTrackedEvent(
  name: name,
  occurredAt: at,
  sequence: sequence,
  properties: properties,
);

DwTrackEvents batch(String installId, List<DwTrackedEvent> events) =>
    DwTrackEvents(
      installId: installId,
      platform: DwAnalyticsPlatform.android,
      appVersion: '1.2.0+7',
      events: events,
    );
