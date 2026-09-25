import 'dart:async';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
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
      DartwayStarterServer.build(
        database: database.config,
        storage: storage,
        port: 0,
        auth: AppAuth.config(
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
    final http = DwCountingTransport();
    final live = DwRecordingConnector();
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
    final kind = DwIdentifierKind.of(identifier);
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
  final DwCountingTransport http;
  final DwRecordingConnector live;
}

final class AppMember {
  AppMember(this._connection, this.session, this._harness);

  final AppClient _connection;
  final DwAuthSession session;
  final AppHarness _harness;

  DwAppClient get client => _connection.client;
  DwCountingTransport get http => _connection.http;
  DwRecordingConnector get live => _connection.live;
  int get accountId => session.id;

  Future<UserProfileRow> profileRow() async => (await _harness.db.userProfiles
      .findFirst(where: (t) => t.accountId.equals(accountId)))!;

  Future<int> get profileId async => (await profileRow()).id!;

  /// Watches [request] and waits until it is live.
  Future<DwRequestWatch<R>> watch<R>(DwDataRequest<R> request) async {
    final watch = client.watch(request);
    addTearDown(watch.close);
    await dwWaitUntil(() => watch.isLive, reason: '$request goes live');
    return watch;
  }

  Future<DwRequestWatch<DwTablePage<T>>> watchTable<T extends DwDataObject>(
    DwTableRequest<T> request,
  ) async {
    final watch = client.watchTable(request);
    addTearDown(watch.close);
    await dwWaitUntil(() => watch.isLive, reason: '$request goes live');
    return watch;
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
