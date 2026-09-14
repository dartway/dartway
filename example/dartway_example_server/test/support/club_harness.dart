import 'dart:async';
import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

/// One example server on its own throwaway database for a test file, and
/// members signed in to it through the real client.
final class ClubHarness {
  ClubHarness._(this.database, this.server);

  final DwTestDatabase database;
  final DwTestServer server;

  /// The codes the server delivered, by normalized phone.
  final Map<String, String> delivered = {};

  static Future<ClubHarness> start({
    DwServerSettings settings = const DwServerSettings(),
  }) async {
    final database = await DwTestDatabase.create(prefix: 'dw_example_test');
    late final ClubHarness harness;
    final server = await DwTestServer.start(
      buildExampleServer(
        database: database.config,
        port: 0,
        settings: settings,
        auth: DwAuthConfig(
          normalize: exampleAuth.normalize,
          onAccountCreated: exampleAuth.onAccountCreated,
          deliverCode: (ctx, kind, identifier, code) async =>
              harness.delivered[identifier] = code,
        ),
      ),
    );
    return harness = ClubHarness._(database, server);
  }

  Future<void> stop() async {
    await server.stop();
    await database.drop();
  }

  DwDatabaseHandle get db => server.db;

  /// A member signed up by phone and code through a real client, with
  /// [name] collected at registration.
  Future<ClubMember> member(String phone, String name) async {
    final http = CountingTransport(DwHttpClientTransport());
    final live = RecordingConnector();
    final client = await server.connectClient(
      httpTransport: http,
      liveConnector: live,
    );
    addTearDown(client.stop);
    final ticket = await client.command(
      DwRequestCode(kind: DwIdentifierKind.phone, identifier: phone),
    );
    final session = await client.command(
      DwVerifyCode(
        ticketId: ticket.valueOrThrow.id,
        code: delivered[normalizePhone(phone)]!,
        registration: {'firstName': name},
      ),
    );
    await client.signIn(session.valueOrThrow);
    return ClubMember(client, session.valueOrThrow, http, live);
  }

  /// A signed-up member promoted to [role] directly in the database, as an
  /// admin would.
  Future<ClubMember> memberWithRole(
    String phone,
    String name,
    UserRole role,
  ) async {
    final member = await this.member(phone, name);
    final row = (await db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(member.accountId),
    ))!;
    await db.userProfiles.update(row.copyWith(role: role));
    return member;
  }
}

final class ClubMember {
  ClubMember(this.client, this.session, this.http, this.live);

  final DwAppClient client;
  final DwAuthSession session;
  final CountingTransport http;
  final RecordingConnector live;

  int get accountId => session.id;
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

/// Real HTTP, counting the calls per wire name.
final class CountingTransport implements DwHttpTransport {
  CountingTransport(this._inner);

  final DwHttpTransport _inner;
  final Map<String, int> _posts = {};

  int posts(String wireName) => _posts[wireName] ?? 0;

  @override
  Future<DwHttpReply> post(DwHttpPost post) {
    final wireName = post.url.pathSegments.last;
    _posts.update(wireName, (n) => n + 1, ifAbsent: () => 1);
    return _inner.post(post);
  }

  @override
  void close() => _inner.close();
}

/// The real live socket, with every frame the server sent recorded.
final class RecordingConnector implements DwLiveConnector {
  final DwLiveConnector _inner = const DwWebSocketConnector();
  final List<Map<String, Object?>> received = [];

  /// The `upd` frames received on [channel].
  List<Map<String, Object?>> updatesOn(DwLiveChannel channel) => [
    for (final frame in received)
      if (frame['k'] == 'upd' && frame['ch'] == channel.wireName) frame,
  ];

  /// The refusals of subscriptions to [channel].
  List<Map<String, Object?>> refusalsOf(DwLiveChannel channel) => [
    for (final frame in received)
      if (frame['k'] == 'subno' && frame['ch'] == channel.wireName) frame,
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
