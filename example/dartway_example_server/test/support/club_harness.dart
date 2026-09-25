import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/people.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

/// One example server on its own throwaway database for a test file, and
/// members signed in to it through the real client.
final class ClubHarness {
  ClubHarness._(this.database, this.server);

  final DwTestDatabase database;
  final DwTestServer server;

  /// The codes the server delivered, by normalized phone.
  final Map<String, String> delivered = {};

  /// With [storage], the server takes uploads on its buckets.
  static Future<ClubHarness> start({
    DwServerSettings settings = const DwServerSettings(),
    DwFileStorageConfig? storage,
    DwPushModule? push,
  }) async {
    final database = await DwTestDatabase.create(prefix: 'dw_example_test');
    late final ClubHarness harness;
    final server = await DwTestServer.start(
      ExampleServer.build(
        database: database.config,
        storage: storage,
        port: 0,
        settings: settings,
        push: push,
        auth: DwAuthConfig(
          normalize: ExampleAuth.config.normalize,
          onAccountCreated: ExampleAuth.config.onAccountCreated,
          onIdentifierChanged: ExampleAuth.config.onIdentifierChanged,
          onAccountDeleting: ExampleAuth.config.onAccountDeleting,
          deliverCode: (ctx, kind, identifier, code, accountId) async =>
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
  /// [name] and the [marketing] consent collected at registration.
  Future<ClubMember> member(
    String phone,
    String name, {
    bool marketing = false,
  }) async {
    final http = DwCountingTransport();
    final live = DwRecordingConnector();
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
        code: delivered[ExampleAuth.normalizePhone(phone)]!,
        registration: {'firstName': name, 'marketing': '$marketing'},
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
    UserRole role, {
    bool marketing = false,
  }) async {
    final member = await this.member(phone, name, marketing: marketing);
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
  final DwCountingTransport http;
  final DwRecordingConnector live;

  int get accountId => session.id;
}

/// The data of a watched request, when it has data.
R? dataOf<R>(DwRequestState<R> state) => switch (state) {
  DwRequestData(:final value) => value,
  _ => null,
};
