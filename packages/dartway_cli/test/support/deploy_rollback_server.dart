import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';

// Compiled into the real server image used by the deploy rollback proof.
Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    final host = arguments[1];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(
        Uri.parse('http://$host:8080/health'),
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw StateError('/health ${response.statusCode}');
      }
      print('/health 200');
    } finally {
      client.close(force: true);
    }
    if (arguments.first == 'probe') {
      final socket = await WebSocket.connect(
        'ws://$host:8080/dw/live?'
        '${DwHttpContract.liveProtocolParameter}=$dwProtocolVersion',
      );
      try {
        final hello =
            jsonDecode(
                  await socket.first.timeout(const Duration(seconds: 5))
                      as String,
                )
                as Map<String, Object?>;
        if (hello['k'] != 'hello' || hello['connection'] is! String) {
          throw StateError('expected live hello, got $hello');
        }
        print('/dw/live hello');
      } finally {
        await socket.close();
      }
    }
    return;
  }
  final server = DwAppServer(
    protocol: DwWireProtocol.core,
    migrations: File('/migration').readAsStringSync().trim() == 'fail'
        ? const [_FailingMigration()]
        : const [],
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
    auth: DwAuthConfig(
      accountDeletion: DwAccountDeletion.byOperator,
      normalize: (kind, raw) => null,
      deliverCode: (ctx, kind, identifier, code, accountId) async {},
    ),
    features: const [],
  );
  await server.start(
    migrateOnly: Platform.environment['DW_MIGRATE_ONLY'] == 'true',
  );
}

final class _FailingMigration extends DwDatabaseMigration {
  const _FailingMigration();

  @override
  String get id => '20261010_120000_missing_table';

  @override
  String get checksum => 'missing-table-fixture';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.sql('CREATE TABLE rollback_marker (id bigint PRIMARY KEY)');
    await m.sql('ALTER TABLE deliberately_missing ADD COLUMN name text');
  }
}
