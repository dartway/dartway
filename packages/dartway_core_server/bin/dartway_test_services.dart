// Internal CLI worker: uses the project's resolved server dependencies rather
// than making the CLI carry a Postgres driver and an S3 signer of its own.
import 'dart:convert';
import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:dartway_core_server/src/files/dw_file_storage.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:dartway_core_server/src/testing/dw_test_run.dart';

Future<void> main(List<String> args) async {
  // The parent owns interruption and waits for this sweep. A second Ctrl-C
  // from the terminal must not abandon run-owned resources halfway through.
  final interrupt = args.firstOrNull == 'cleanup'
      ? ProcessSignal.sigint.watch().listen((_) {})
      : null;
  final run = testRunId()!;
  var failed = false;
  for (final service in args.skip(1)) {
    try {
      if (service == 'database') {
        final env = Platform.environment;
        final db = await DwPostgresDatabase.open(
          DwDatabaseConfig(
            host: env['DW_DATABASE_HOST']!,
            port: int.parse(env['DW_DATABASE_PORT']!),
            name: env['DW_DATABASE_NAME']!,
            user: env['DW_DATABASE_USER']!,
            password: env['DW_DATABASE_PASSWORD']!,
            ssl: false,
            maxConnections: 1,
            queryTimeout: const Duration(seconds: 15),
          ),
        );
        try {
          if (args.first == 'cleanup') {
            final pattern = RegExp('^dw_test_${run}_[a-z0-9]{10}\$');
            for (final row in await db.db.query(
              'SELECT datname FROM pg_database',
            )) {
              final name = row['datname']! as String;
              if (pattern.hasMatch(name)) {
                await db.db.execute(
                  'DROP DATABASE IF EXISTS "$name" WITH (FORCE)',
                );
              }
            }
          } else {
            final rows = await db.db.query(
              'SELECT rolcreatedb OR rolsuper AS allowed FROM pg_roles WHERE rolname = current_user',
            );
            if (rows.single['allowed'] != true) {
              throw StateError('The test database role needs CREATEDB');
            }
          }
        } finally {
          await db.close();
        }
      } else {
        final store = DwObjectStore(
          DwFileStorageConfig.fromEnvironment(Platform.environment),
          requestTimeout: const Duration(seconds: 15),
        );
        try {
          final body = await read(store, 'GET', '');
          if (args.first != 'cleanup') continue;
          final pattern = RegExp('^dw-test-$run-(pub|prv)-[a-z0-9]{10}\$');
          for (final bucket in tags(body, 'Name').where(pattern.hasMatch)) {
            // Delete each page before listing again: no continuation token can
            // become stale as objects disappear, and no 1000-object limit leaks.
            Set<String>? previousPage;
            while (true) {
              final listing = await read(
                store,
                'GET',
                bucket,
                query: [('list-type', '2'), ('encoding-type', 'url')],
              );
              final keys = tags(
                listing,
                'Key',
              ).map(Uri.decodeQueryComponent).toList();
              if (keys.isEmpty) break;
              final page = keys.toSet();
              if (previousPage != null &&
                  page.length == previousPage.length &&
                  page.containsAll(previousPage)) {
                throw const _CleanupStalled();
              }
              previousPage = page;
              for (final key in keys) {
                await store.delete(bucket, key);
              }
            }
            await read(store, 'DELETE', bucket);
          }
        } finally {
          store.close();
        }
      }
    } catch (error) {
      // Driver/HTTP errors can contain supplied credentials; do not echo them.
      stderr.writeln(
        'Test $service ${args.first} failed '
        '(${error is _CleanupStalled ? 'S3 cleanup made no progress' : error.runtimeType}). '
        'Check connectivity and permissions (CREATEDB for Postgres, bucket '
        'listing and deletion for S3); run id: $run.',
      );
      failed = true;
    }
  }
  await interrupt?.cancel();
  exitCode = failed ? 1 : 0;
}

Future<String> read(
  DwObjectStore store,
  String method,
  String bucket, {
  List<(String, String)> query = const [],
}) async {
  final response = await store.send(method, bucket: bucket, query: query);
  final body = await utf8
      .decodeStream(response)
      .timeout(const Duration(seconds: 15));
  if (response.statusCode >= 300) {
    throw DwStorageException(method, response.statusCode);
  }
  return body;
}

Iterable<String> tags(String xml, String tag) sync* {
  for (final match in RegExp('<$tag>([^<]*)</$tag>').allMatches(xml)) {
    yield match
        .group(1)!
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }
}

final class _CleanupStalled implements Exception {
  const _CleanupStalled();
}
