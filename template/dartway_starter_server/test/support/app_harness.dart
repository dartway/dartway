import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';
import 'package:dartway_starter_server/src/entities/people.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

/// One server on its own throwaway database for a test file, and members
/// signed in to it through the real client — real HTTP, the real live socket.
///
/// `DW_DATABASE_*` names the Postgres server and its maintenance database
/// (`DW_DATABASE_NAME=postgres`); each file creates and drops its own.
/// `dartway test` provides both.
final class AppHarness {
  AppHarness._(this.database, this.server);

  final DwTestDatabase database;
  final DwTestServer server;

  /// The codes the server delivered, by stored identifier.
  final Map<String, String> delivered = {};

  /// With [storage], the server takes uploads on its buckets.
  static Future<AppHarness> start({DwFileStorageConfig? storage}) async {
    final database = await DwTestDatabase.create(prefix: 'app_test');
    late final AppHarness harness;
    final server = await DwTestServer.start(
      buildDartwayStarterServer(
        database: database.config,
        storage: storage,
        port: 0,
        auth: appAuth(
          // Tests ask one identifier for several codes within a minute.
          resendDelay: Duration.zero,
          deliverCode: (ctx, kind, identifier, code) async =>
              harness.delivered[identifier] = code,
        ),
      ),
    );
    return harness = AppHarness._(database, server);
  }

  Future<void> stop() async {
    await server.stop();
    await database.drop();
  }

  DwDatabaseHandle get db => server.db;

  /// A started client of this server, stopped with the test.
  Future<AppClient> client() async {
    final http = CountingTransport(DwHttpClientTransport());
    final live = RecordingConnector();
    final client = await server.connectClient(
      httpTransport: http,
      liveConnector: live,
    );
    addTearDown(client.stop);
    return AppClient(client, http, live);
  }

  /// Asks for a code for [identifier] and answers the ticket and the code
  /// that arrived.
  Future<({DwCodeTicket ticket, String code})> requestCode(
    DwAppClient client,
    String identifier,
  ) async {
    final kind = AuthIdentifier.kindOf(identifier);
    final ticket = (await client.command(
      DwRequestCode(kind: kind, identifier: identifier),
    )).valueOrThrow;
    return (
      ticket: ticket,
      code: delivered[AuthIdentifier.normalize(kind, identifier)]!,
    );
  }

  /// A member signed up by [identifier] and a delivered code, with the
  /// consent the app collects.
  Future<AppMember> signUp(
    String identifier, {
    String? firstName,
    bool marketing = false,
  }) async {
    final member = await client();
    final (:ticket, :code) = await requestCode(member.client, identifier);
    final session = (await member.client.command(
      DwVerifyCode(
        ticketId: ticket.id,
        code: code,
        registration: consents(firstName: firstName, marketing: marketing),
      ),
    )).valueOrThrow;
    await member.client.signIn(session);
    return AppMember(member, session, this);
  }

  /// An administrator: signed up, then promoted in the database.
  Future<AppMember> admin(String identifier, String firstName) async {
    final member = await signUp(identifier, firstName: firstName);
    final row = await member.profileRow();
    await db.userProfiles.update(row.copyWith(role: UserRole.admin));
    return member;
  }
}

/// What the app sends with a code: the terms accepted.
Map<String, String> consents({String? firstName, bool marketing = false}) => {
  RegistrationKeys.terms: 'true',
  RegistrationKeys.marketing: '$marketing',
  RegistrationKeys.firstName: ?firstName,
};

final class AppClient {
  AppClient(this.client, this.http, this.live);

  final DwAppClient client;
  final CountingTransport http;
  final RecordingConnector live;
}

final class AppMember {
  AppMember(this._connection, this.session, this._harness);

  final AppClient _connection;
  final DwAuthSession session;
  final AppHarness _harness;

  DwAppClient get client => _connection.client;
  CountingTransport get http => _connection.http;
  RecordingConnector get live => _connection.live;
  int get accountId => session.id;

  Future<UserProfileRow> profileRow() async => (await _harness.db.userProfiles
      .findFirst(where: (t) => t.accountId.equals(accountId)))!;

  Future<int> get profileId async => (await profileRow()).id!;

  /// Watches [request] and waits until it is live.
  Future<DwRequestWatch<R>> watch<R>(DwDataRequest<R> request) async {
    final watch = client.watch(request);
    addTearDown(watch.close);
    await eventually(() => watch.isLive, reason: '$request goes live');
    return watch;
  }

  Future<DwRequestWatch<DwTablePage<T>>> watchTable<T extends DwDataObject>(
    DwTableRequest<T> request,
  ) async {
    final watch = client.watchTable(request);
    addTearDown(watch.close);
    await eventually(() => watch.isLive, reason: '$request goes live');
    return watch;
  }
}

/// Waits until [condition] holds.
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('not met within $timeout${reason == null ? '' : ': $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// The data of a watched request, when it has data.
R? dataOf<R>(DwRequestState<R> state) => switch (state) {
  DwRequestData(:final value) => value,
  _ => null,
};

/// A refused result with [code].
Matcher refusedWith(DwRefusalCode code) => isA<DwCallRefused<Object?>>().having(
  (result) => result.refusal.code,
  'refusal code',
  code.code,
);

/// Real HTTP, counting the calls per wire name and keeping the last answer
/// to each.
final class CountingTransport implements DwHttpTransport {
  CountingTransport(this._inner);

  final DwHttpTransport _inner;
  final Map<String, int> _posts = {};
  final Map<String, DwHttpReply> _replies = {};

  int posts(String wireName) => _posts[wireName] ?? 0;

  /// The body of the last answer to [wireName], decoded.
  Map<String, Object?> lastReply(String wireName) =>
      jsonDecode(_replies[wireName]!.body) as Map<String, Object?>;

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    final wireName = post.url.pathSegments.last;
    _posts.update(wireName, (n) => n + 1, ifAbsent: () => 1);
    return _replies[wireName] = await _inner.post(post);
  }

  @override
  void close() => _inner.close();
}

/// The real live socket, with every frame the server sent recorded.
final class RecordingConnector implements DwLiveConnector {
  final DwLiveConnector _inner = const DwWebSocketConnector();
  final List<Map<String, Object?>> received = [];

  /// The `closed` frames of [channel].
  List<Map<String, Object?>> closuresOf(DwLiveChannel channel) => [
    for (final frame in received)
      if (frame['k'] == 'closed' && frame['ch'] == channel.wireName) frame,
  ];

  @override
  Future<DwLiveConnection> connect(Uri url) async =>
      _RecordingConnection(await _inner.connect(url), received);
}

final class _RecordingConnection implements DwLiveConnection {
  _RecordingConnection(this._inner, this._received);

  final DwLiveConnection _inner;
  final List<Map<String, Object?>> _received;

  @override
  late final Stream<String> messages = _inner.messages.map((frame) {
    _received.add(jsonDecode(frame) as Map<String, Object?>);
    return frame;
  });

  @override
  void send(String frame) => _inner.send(frame);

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> close([int? code, String? reason]) => _inner.close(code, reason);
}

/// A GET without credentials — what a browser showing a public URL does.
Future<({int status, List<int> bytes})> getAnonymously(String url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    return (status: response.statusCode, bytes: bytes);
  } finally {
    client.close(force: true);
  }
}
