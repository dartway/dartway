import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_feature_imports.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server's features form a graph without cycles, `core/` imports none of
/// them, and a feature imports another only through its surface (#382).
/// Every rule has a case that passes and one that fails.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_feature_imports');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// A server package `my_server` holding [files] under `lib/src/`, and the
  /// inspector's verdict on it.
  DwFeatureImportInspector inspect(
    Map<String, String> files, {
    DwCheckType? only,
  }) {
    final server = Directory(p.join(sandbox.path, 'my_server'));
    File(p.join(server.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: my_server\n');
    for (final MapEntry(key: path, value: source) in files.entries) {
      File(p.join(server.path, 'lib', 'src', path))
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }
    return DwFeatureImportInspector(serverPackageDir: server, filterType: only)
      ..run();
  }

  String imports(List<String> paths) => [
    for (final path in paths) "import 'package:my_server/src/$path';",
  ].join('\n');

  group('the surface', () {
    test('rows, access, objects, publications and changes, and their parts, '
        'pass', () {
      final inspector = inspect({
        'chat/chat_handlers.dart': imports([
          'profile/profile_rows.dart',
          'profile/profile_access.dart',
          'profile/profile_objects.dart',
          'profile/profile_publications.dart',
          'profile/profile_changes.dart',
          'profile/profile_photos_rows.dart',
          'core/channels.dart',
          'chat/logic/pricing.dart',
        ]),
        'chat/logic/pricing.dart': imports(['profile/profile_rows.dart']),
        'profile/profile_rows.dart': '',
      });
      expect(inspector.surfaceFindings, isEmpty);
      expect(inspector.cycleFindings, isEmpty);
      expect(inspector.coreFindings, isEmpty);
    });

    test('handlers, jobs, routes, the feature file and logic/ fail', () {
      final inspector = inspect({
        'chat/chat_handlers.dart': imports([
          'profile/profile_handlers.dart',
          'profile/profile_jobs.dart',
          'profile/profile_routes.dart',
          'profile/profile_feature.dart',
          'profile/logic/avatar_client.dart',
          'profile/profile_hooks.dart',
        ]),
      });
      expect(inspector.surfaceFindings, hasLength(6));
      expect(
        inspector.surfaceFindings.first,
        allOf(
          startsWith(
            'chat/chat_handlers.dart:1 imports profile/profile_handlers.dart',
          ),
          contains(
            'profile_rows, profile_access, profile_objects, '
            'profile_publications, profile_changes',
          ),
        ),
      );
    });

    test('a relative import is resolved like a package: one', () {
      final inspector = inspect({
        'chat/logic/pricing.dart':
            "import '../../profile/profile_handlers.dart';\n"
            "import '../chat_rows.dart';",
      });
      expect(inspector.surfaceFindings, [
        startsWith(
          'chat/logic/pricing.dart:1 imports profile/profile_handlers.dart',
        ),
      ]);
    });

    test('an export counts, and a conditional import\'s alternatives too', () {
      final inspector = inspect({
        'chat/chat_objects.dart':
            "export 'package:my_server/src/profile/profile_handlers.dart';\n"
            "import 'package:my_server/src/profile/profile_rows.dart'\n"
            "    if (dart.library.io) "
            "'package:my_server/src/profile/logic/io.dart';",
      });
      expect(inspector.surfaceFindings, [
        contains('imports profile/profile_handlers.dart'),
        contains('imports profile/logic/io.dart'),
      ]);
    });

    test('a directive in a comment or a string is not one', () {
      final inspector = inspect({
        'chat/chat_handlers.dart':
            "// import 'package:my_server/src/profile/profile_handlers.dart';\n"
            "const text = '''\n"
            "import 'package:my_server/src/profile/profile_handlers.dart';\n"
            "''';",
      });
      expect(inspector.surfaceFindings, isEmpty);
    });

    test('its own files, the generated schema and packages are not judged', () {
      final inspector = inspect({
        'chat/chat_handlers.dart':
            '${imports(['chat/chat_jobs.dart', 'chat/logic/pricing.dart'])}\n'
            "import 'package:my_server/generated/dw_schema.dart';\n"
            "import 'package:other/src/profile/profile_handlers.dart';",
      });
      expect(inspector.surfaceFindings, isEmpty);
    });
  });

  group('core/', () {
    test('importing a feature fails, in any kind', () {
      final inspector = inspect({
        'core/call_context.dart': imports(['profile/profile_rows.dart']),
        'core/push/app_push.dart': imports(['chat/chat_access.dart']),
      });
      expect(inspector.coreFindings, [
        startsWith(
          'core/call_context.dart:1 imports profile/profile_rows.dart',
        ),
        startsWith('core/push/app_push.dart:1 imports chat/chat_access.dart'),
      ]);
      // Said once, as core's, not again as a surface question.
      expect(inspector.surfaceFindings, isEmpty);
    });

    test('importing core/, and core/ importing itself, pass', () {
      final inspector = inspect({
        'core/environment.dart': imports(['core/files.dart']),
        'chat/chat_handlers.dart': imports(['core/channels.dart']),
      });
      expect(inspector.coreFindings, isEmpty);
    });
  });

  group('cycles', () {
    test('two features importing each other, through the surface, fail', () {
      final inspector = inspect({
        'chat/chat_objects.dart': imports(['profile/profile_objects.dart']),
        'profile/profile_objects.dart': imports(['chat/chat_rows.dart']),
      });
      expect(inspector.cycleFindings, [
        startsWith(
          'chat → profile → chat: chat → profile '
          '(chat/chat_objects.dart:1); profile → chat '
          '(profile/profile_objects.dart:1)',
        ),
      ]);
    });

    test('a knot prints its shortest cycle, which need not pass its first '
        'feature, and names the rest', () {
      final inspector = inspect({
        'a/a_rows.dart': imports(['b/b_rows.dart']),
        'b/b_rows.dart': imports(['c/c_rows.dart']),
        'c/c_rows.dart': imports(['a/a_rows.dart', 'd/d_rows.dart']),
        'd/d_rows.dart': imports(['c/c_rows.dart']),
        'e/e_rows.dart': imports(['a/a_rows.dart']),
      });
      expect(inspector.cycleFindings, [
        allOf(startsWith('c → d → c:'), contains('and a, b in the same knot')),
      ]);
    });

    test('among cycles of one length, the first feature\'s is printed', () {
      final inspector = inspect({
        'a/a_rows.dart': imports(['b/b_rows.dart']),
        'b/b_rows.dart': imports(['a/a_rows.dart', 'c/c_rows.dart']),
        'c/c_rows.dart': imports(['d/d_rows.dart']),
        'd/d_rows.dart': imports(['b/b_rows.dart']),
      });
      expect(inspector.cycleFindings, [
        allOf(startsWith('a → b → a:'), contains('and c, d in the same knot')),
      ]);
    });

    test('a graph without cycles passes, however deep', () {
      final inspector = inspect({
        'account/account_feature.dart': imports([
          'profile/profile_rows.dart',
          'admin/admin_publications.dart',
        ]),
        'admin/admin_handlers.dart': imports([
          'profile/profile_objects.dart',
          'profile/profile_access.dart',
        ]),
        'chat/chat_handlers.dart': imports(['profile/profile_access.dart']),
      });
      expect(inspector.cycleFindings, isEmpty);
    });

    test('a knot made by an import outside the surface is still a knot', () {
      final inspector = inspect({
        'chat/chat_handlers.dart': imports(['issues/logic/holds.dart']),
        'issues/issues_rows.dart': imports(['chat/chat_rows.dart']),
      });
      expect(inspector.cycleFindings, hasLength(1));
      expect(inspector.surfaceFindings, hasLength(1));
    });
  });

  group('what the rules pass over, and what they still see', () {
    test('a surface name one folder down is not the surface', () {
      final inspector = inspect({
        'chat/chat_handlers.dart': imports(['profile/logic/profile_rows.dart']),
      });
      expect(inspector.surfaceFindings, [
        contains('imports profile/logic/profile_rows.dart — outside'),
      ]);
    });

    test('migrations/ importing a feature is not judged', () {
      final inspector = inspect({
        'migrations/m20260930_000000_x.dart': imports([
          'profile/profile_handlers.dart',
        ]),
        'migrations/migrations.dart': imports([
          'migrations/m20260930_000000_x.dart',
        ]),
      });
      expect(inspector.surfaceFindings, isEmpty);
      expect(inspector.coreFindings, isEmpty);
      expect(inspector.cycleFindings, isEmpty);
    });

    test('importing the package\'s library from lib/src/ fails', () {
      final inspector = inspect({
        'chat/chat_handlers.dart': "import 'package:my_server/my_server.dart';",
        'core/files.dart': "import '../../my_server.dart';",
        'profile/profile_rows.dart':
            "import 'package:my_server/generated/dw_schema.dart';",
      });
      expect(inspector.surfaceFindings, [
        startsWith('chat/chat_handlers.dart:1 imports my_server.dart'),
      ]);
      expect(inspector.coreFindings, [
        startsWith('core/files.dart:1 imports my_server.dart'),
      ]);
    });

    test('a part directive counts; a part of does not', () {
      final inspector = inspect({
        'chat/chat_rows.dart':
            "part 'package:my_server/src/profile/logic/shared.dart';\n"
            "part 'chat_rows.dw.dart';",
        'profile/logic/shared.dart': "part of '../../chat/chat_rows.dart';",
      });
      expect(inspector.surfaceFindings, [
        contains('imports profile/logic/shared.dart'),
      ]);
      expect(inspector.cycleFindings, isEmpty);
    });
  });

  group('writes into another feature\'s rows', () {
    const schema = '''
extension MyDb on DwDatabaseHandle {
  DwTableRepository<UserProfileRow, UserProfileTable> get userProfiles =>
      repository(UserProfileRow.tableDef);
  DwTableRepository<ChatMessageRow, ChatMessageTable>
  get chatMessages => repository(ChatMessageRow.tableDef);
}
''';

    DwFeatureImportInspector inspectWrites(Map<String, String> files) {
      File(
          p.join(
            sandbox.path,
            'my_server',
            'lib',
            'generated',
            'dw_schema.dart',
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(schema);
      return inspect({
        'profile/profile_rows.dart':
            "@DwSqlTable('user_profile')\n"
            'final class UserProfileRow extends DwTableRow with _\$UserProfileRow {}',
        'chat/chat_rows.dart':
            'final class ChatMessageRow extends DwTableRow {}',
        ...files,
      });
    }

    test('from another feature or from core/ fail, each call', () {
      final inspector = inspectWrites({
        'admin/admin_handlers.dart': '''
final a = ctx.db.userProfiles.update(row);
final b = db.userProfiles
    .insert(draft);
final c = ctx.db.chatMessages.deleteWhere((t) => t.id.equals(1));
''',
        'core/auth.dart': 'final d = ctx.db.userProfiles.upsert(draft);',
      });
      expect(inspector.writeFindings, [
        startsWith('admin/admin_handlers.dart:1 writes userProfiles (update)'),
        startsWith('admin/admin_handlers.dart:2 writes userProfiles (insert)'),
        allOf(
          startsWith('admin/admin_handlers.dart:4 writes chatMessages'),
          contains(
            "ChatMessageRow is chat's: call a function of chat_changes.dart",
          ),
        ),
        startsWith('core/auth.dart:1 writes userProfiles (upsert)'),
      ]);
    });

    test('through any handle — a transaction\'s, a helper\'s — fail too', () {
      final inspector = inspectWrites({
        'admin/admin_handlers.dart': '''
final a = ctx.db.transaction((tx) async {
  await tx.userProfiles.insert(draft);
});
Future<void> save(DwDatabaseHandle h) => h.chatMessages.update(row);
final b = cache.messages.update(row);
final c = map.update('key', (v) => v);
''',
      });
      expect(inspector.writeFindings, [
        startsWith('admin/admin_handlers.dart:2 writes userProfiles (insert)'),
        startsWith('admin/admin_handlers.dart:4 writes chatMessages (update)'),
      ]);
    });

    test('its own rows, reads, comments and strings pass', () {
      final inspector = inspectWrites({
        'profile/profile_changes.dart':
            'final a = ctx.db.userProfiles.update(row);',
        'profile/logic/tombstone.dart':
            'final a = ctx.db.userProfiles.updateWhere((t) => t, (t) => t);',
        'admin/admin_handlers.dart': '''
final a = ctx.db.userProfiles.findById(1);
final b = ctx.db.userProfiles.count();
// ctx.db.userProfiles.update(row)
const c = 'db.userProfiles.delete(1)';
final d = ProfileChanges.changeRole(ctx, row, role);
''',
        'migrations/m1.dart': 'final a = db.userProfiles.insert(draft);',
      });
      expect(inspector.writeFindings, isEmpty);
    });

    test('without a generated schema, nothing is judged', () {
      final inspector = inspect({
        'admin/admin_handlers.dart': 'final a = ctx.db.userProfiles.update(r);',
      });
      expect(inspector.writeFindings, isEmpty);
    });
  });

  test('--type runs one rule; the tally counts each as an error', () {
    inspect({
      'core/auth.dart': imports(['profile/profile_rows.dart']),
      'chat/chat_rows.dart': imports(['profile/profile_handlers.dart']),
      'profile/profile_rows.dart': imports(['chat/chat_rows.dart']),
    });
    final server = Directory(p.join(sandbox.path, 'my_server'));
    final tally = DwCheckTally();
    expect(
      DwFeatureImportInspector(serverPackageDir: server).run(tally: tally),
      3,
    );
    expect(tally.errors, 3);
    expect(
      DwFeatureImportInspector(
        serverPackageDir: server,
        filterType: DwCheckType.coreImportsFeature,
      ).run(),
      1,
    );
  });

  test('no server package, or no lib/src/, says nothing', () {
    expect(DwFeatureImportInspector(serverPackageDir: null).run(), 0);
    expect(
      DwFeatureImportInspector(
        serverPackageDir: Directory(p.join(sandbox.path, 'absent')),
      ).run(),
      0,
    );
  });
}
