import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

/// One server on its own throwaway database for a test file, and members
/// signed in to it through the real client — real HTTP, the real live socket.
///
/// The skeleton's harness, extended: the club starts with push and settings
/// of its own, signs in by phone, and has staff besides admins.
final class AppHarness {
  AppHarness._(this.database, this.server);

  final DwTestDatabase database;
  final DwTestServer server;

  /// The codes the server delivered, by normalized phone.
  final Map<String, String> delivered = {};

  /// With [storage], the server takes uploads on its buckets.
  static Future<AppHarness> start({
    DwServerSettings settings = const DwServerSettings(),
    DwFileStorageConfig? storage,
    DwPushModule? push,
  }) async {
    final database = await DwTestDatabase.create(prefix: 'dw_example_test');
    late final AppHarness harness;
    final server = await DwTestServer.start(
      DartwayExampleServer.build(
        adminIdentifier: null,
        database: database.config,
        storage: storage,
        port: 0,
        settings: settings,
        push: push,
        auth: DwAuthConfig(
          accountDeletion: DwAccountDeletion.byMember,
          normalize: AppAuth.config.normalize,
          onAccountCreated: AppAuth.config.onAccountCreated,
          onIdentifierChanged: AppAuth.config.onIdentifierChanged,
          onAccountDeleting: AppAuth.config.onAccountDeleting,
          deliverCode: (ctx, kind, identifier, code, accountId) async =>
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

  /// A member signed up by [phone] and a delivered code, with [firstName] and
  /// the [marketing] consent collected at registration.
  Future<AppMember> signUp(
    String phone, {
    required String firstName,
    bool marketing = false,
  }) async {
    final member = await client();
    final ticket = await member.client.command(
      DwRequestCode(kind: DwIdentifierKind.phone, identifier: phone),
    );
    final session = (await member.client.command(
      DwVerifyCode(
        ticketId: ticket.valueOrThrow.id,
        code: delivered[AppAuth.normalizePhone(phone)]!,
        registration: {'firstName': firstName, 'marketing': '$marketing'},
      ),
    )).valueOrThrow;
    await member.client.signIn(session);
    return AppMember(member, session, this);
  }

  /// A signed-up member promoted to [role] directly in the database, as an
  /// admin would.
  Future<AppMember> withRole(
    String phone,
    String firstName,
    UserRole role, {
    bool marketing = false,
  }) async {
    final member = await signUp(
      phone,
      firstName: firstName,
      marketing: marketing,
    );
    final row = await member.profileRow();
    await db.userProfiles.update(row.copyWith(role: role));
    return member;
  }

  /// An administrator: signed up, then promoted in the database.
  Future<AppMember> admin(String phone, String firstName) =>
      withRole(phone, firstName, UserRole.admin);

  /// A staff member: signed up, then promoted in the database.
  Future<AppMember> staff(String phone, String firstName) =>
      withRole(phone, firstName, UserRole.staff);
}

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
