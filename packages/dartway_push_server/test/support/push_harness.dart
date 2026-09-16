import 'dart:async';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestAnswer, DwTestCaller, DwTestDatabase, DwTestServer;
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

import 'package:dartway_push_server/testing.dart';

// --- the test protocol ------------------------------------------------------

enum TestCategory with DwPushCategory { news, security }

/// A project payload, written as `dartway generate` writes one.
final class NewsAlert extends DwDataObject {
  const NewsAlert({required this.id, required this.title});

  @override
  final int id;
  final String title;

  @override
  String get dwTypeName => 'NewsAlert';

  @override
  Map<String, Object?> toJson() => {'id': id, 'title': title};

  static NewsAlert fromJson(Map<String, Object?> json) =>
      NewsAlert(id: json['id']! as int, title: json['title']! as String);

  @override
  bool operator ==(Object other) =>
      other is NewsAlert && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// Queues a push through `ctx.push.send` in the command's transaction, then
/// refuses when [refuse] — rolling the send back.
final class QueueAlert extends DwActionCommand<int> {
  const QueueAlert({
    required this.recipients,
    this.title = 'Pool closed',
    this.dedupKey,
    this.delayMillis,
    this.lifetimeMillis,
    this.refuse = false,
    this.category = 'news',
    this.image,
  });

  final List<int> recipients;
  final String title;
  final String? dedupKey;
  final int? delayMillis;
  final int? lifetimeMillis;
  final bool refuse;
  final String category;
  final String? image;

  @override
  String get dwTypeName => 'QueueAlert';

  @override
  Map<String, Object?> toJson() => {
    'recipients': recipients,
    'title': title,
    'dedupKey': ?dedupKey,
    'delayMillis': ?delayMillis,
    'lifetimeMillis': ?lifetimeMillis,
    'refuse': refuse,
    'category': category,
    'image': ?image,
  };

  static QueueAlert fromJson(Map<String, Object?> json) => QueueAlert(
    recipients: (json['recipients']! as List).cast<int>(),
    title: json['title']! as String,
    dedupKey: json['dedupKey'] as String?,
    delayMillis: json['delayMillis'] as int?,
    lifetimeMillis: json['lifetimeMillis'] as int?,
    refuse: json['refuse']! as bool,
    category: json['category']! as String,
    image: json['image'] as String?,
  );
}

final DwWireProtocol testProtocol = DwWireProtocol([
  ...dwPushProtocolEntries,
  const DwProtocolEntry<NewsAlert>('NewsAlert', NewsAlert.fromJson),
  const DwProtocolEntry<QueueAlert>('QueueAlert', QueueAlert.fromJson),
], include: DwWireProtocol.core);

final DwCallHandler queueAlertHandler = DwCallHandler.command<QueueAlert, int>(
  access: DwAccessRule.anonymous,
  handle: (ctx, command) async {
    final queued = await ctx.push.send(
      command.recipients,
      message: DwPushMessage(
        title: command.title,
        body: 'Maintenance day.',
        data: const NewsAlert(id: 12, title: 'Pool closed'),
        link: '/news/12',
        imageUrl: command.image,
      ),
      category: TestCategory.values.byName(command.category),
      dedupKey: command.dedupKey,
      scheduledAt: command.delayMillis == null
          ? null
          : DateTime.now().add(Duration(milliseconds: command.delayMillis!)),
      lifetime: command.lifetimeMillis == null
          ? null
          : Duration(milliseconds: command.lifetimeMillis!),
    );
    if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
    return queued;
  },
);

// --- the harness ------------------------------------------------------------

final class RecordingLogger implements DwServerLogger {
  RecordingLogger(this.lines, [this.scope]);

  final List<String> lines;
  final String? scope;
  static final bool _echo = Platform.environment['DW_TEST_LOG'] != null;

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final line =
        '${level.name} ${scope ?? ''} $message${error == null ? '' : ': $error'}';
    lines.add(line);
    if (_echo) stderr.writeln(line);
  }

  @override
  DwServerLogger scoped(String scope) => RecordingLogger(
    lines,
    this.scope == null ? scope : '${this.scope} $scope',
  );
}

final class RecordingAlerts implements DwAlertSink {
  final List<DwServerIncident> incidents = [];

  @override
  Future<void> send(
    DwServerIncident incident, {
    String? suppressedNote,
  }) async => incidents.add(incident);
}

typedef TestAccount = ({int id, String token, int keyId});

DwDatabaseConfig adminConfig() {
  try {
    return DwDatabaseConfig.fromEnvironment(Platform.environment);
  } on ArgumentError catch (error) {
    throw StateError(
      'The dartway_push_server suites need a Postgres server: set '
      'DW_DATABASE_HOST, _PORT, _NAME (a maintenance database), _USER, '
      '_PASSWORD and _SSL. ($error)',
    );
  }
}

/// A database, fake FCM and RuStore services and a server with push, for
/// one test file.
final class PushHarness {
  PushHarness._(this.database, this.fcm, this.rustore, this.logs, this.alerts);

  final DwTestDatabase database;
  final DwFakePushService fcm;
  final DwFakePushService rustore;
  final List<String> logs;
  final RecordingAlerts alerts;
  late final DwTestServer server;
  late final DwTestCaller caller;

  /// The eligibility rule the module asks; `null` sends to everyone.
  DwPushEligibility? eligibility;

  static Future<PushHarness> start({
    DwPushSettings settings = testPushSettings,
    DwServerSettings serverSettings = const DwServerSettings(
      jobPollInterval: Duration(seconds: 30),
    ),
    int? maxConnections,
    bool withEligibility = true,
    bool withRuStore = true,
  }) async {
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'push_test',
    );
    final harness = PushHarness._(
      database,
      await DwFakePushService.start(),
      await DwFakePushService.start(),
      [],
      RecordingAlerts(),
    );
    final module = DwPushModule(
      providers: [
        harness.fcm.fcmProvider(
          webLinkBase: Uri.parse('https://app.example.com'),
        ),
        if (withRuStore) harness.rustore.ruStoreProvider(),
      ],
      eligibility: withEligibility
          ? (ctx, notice, accountIds) async =>
                await harness.eligibility?.call(ctx, notice, accountIds) ??
                const {}
          : null,
      settings: settings,
    );
    final config = maxConnections == null
        ? database.config
        : database.config.copyWith(maxConnections: maxConnections);
    try {
      harness.server = await DwTestServer.start(
        DwAppServer(
          protocol: testProtocol,
          migrations: const [],
          database: config,
          auth: DwAuthConfig(
            normalize: (kind, raw) => raw.trim().toLowerCase(),
            deliverCode: (ctx, kind, identifier, code) async {},
          ),
          handlers: [queueAlertHandler],
          modules: [module],
          logger: RecordingLogger(harness.logs),
          alerts: harness.alerts,
          settings: serverSettings,
        ),
      );
    } catch (_) {
      await harness.fcm.close();
      await harness.rustore.close();
      await database.drop();
      rethrow;
    }
    harness.caller = harness.server.caller();
    return harness;
  }

  DwDatabaseHandle get db => server.db;

  int _accounts = 0;

  /// A new account with a personal key.
  Future<TestAccount> account() async {
    final accounts = server.server.accounts;
    final ensured = await accounts.ensure(
      DwIdentifierKind.email,
      'member${++_accounts}-${DateTime.now().microsecondsSinceEpoch}@test',
    );
    final issued = await accounts.issueKey(ensured.accountId, label: 'test');
    return (id: ensured.accountId, token: issued.token, keyId: issued.key.id);
  }

  /// Registers [deviceToken] for [account] through the command.
  Future<DwTestAnswer> register(
    TestAccount account,
    String deviceToken, {
    DwPushTransport transport = DwPushTransport.fcm,
    DwPushPlatform platform = DwPushPlatform.android,
  }) async {
    final caller = server.caller(token: account.token);
    try {
      return await caller.call(
        DwRegisterPushToken(
          transport: transport,
          token: deviceToken,
          platform: platform,
        ),
      );
    } finally {
      caller.close();
    }
  }

  /// An account with one FCM device registered.
  Future<TestAccount> member(String deviceToken) async {
    final account = await this.account();
    final answer = await register(account, deviceToken);
    expect(answer.status, 200, reason: answer.text);
    return account;
  }

  Future<DwTestAnswer> queue(QueueAlert alert) => caller.call(alert);

  Future<List<DwResultRow>> deliveries() =>
      db.query('SELECT * FROM dw_push_delivery ORDER BY id');

  Future<List<DwResultRow>> devices() =>
      db.query('SELECT * FROM dw_push_device ORDER BY id');

  Future<void> stop() async {
    caller.close();
    await server.stop();
    await fcm.close();
    await rustore.close();
    await database.drop();
  }
}

/// Short retries, so a test sees them.
const DwPushSettings testPushSettings = DwPushSettings(
  backoff: _testBackoff,
  maxAttempts: 3,
  sendTimeout: Duration(seconds: 5),
);

Duration _testBackoff(int attempt) => const Duration(milliseconds: 200);

PushHarness Function() usePushHarness({
  DwPushSettings settings = testPushSettings,
  DwServerSettings serverSettings = const DwServerSettings(
    jobPollInterval: Duration(seconds: 30),
  ),
  int? maxConnections,
  bool withRuStore = true,
}) {
  PushHarness? harness;
  setUpAll(
    () async => harness = await PushHarness.start(
      settings: settings,
      serverSettings: serverSettings,
      maxConnections: maxConnections,
      withRuStore: withRuStore,
    ),
  );
  tearDownAll(() async => harness?.stop());
  return () => harness!;
}

/// Polls [condition] until it holds or [timeout] passes.
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'condition not met within $timeout${reason == null ? '' : ': $reason'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
