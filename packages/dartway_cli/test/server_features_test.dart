import 'dart:io';

import 'package:dartway_cli/src/checker/dw_server_features.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Inside a server feature the file set is closed, and each file holds what
/// its name says (#381). Every rule has a case that passes and one that fails:
/// a rule that never passes anything is as useless as one that never fails.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_server_features');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// The shared package every case sees: two data objects, one through a base
  /// of the project's own, and a command that is not a data object.
  void writeShared() {
    final file = File(p.join(sandbox.path, 'my_shared', 'lib', 'chat.dart'))
      ..createSync(recursive: true);
    file.writeAsStringSync('''
final class ChatMessage extends DwDataObject with _\$ChatMessage {}
abstract class Card extends DwDataObject {}
final class PersonCard extends Card with _\$PersonCard {}
final class SendMessage extends DwActionCommand<ChatMessage> {}
''');
  }

  /// A server package holding [files] under `lib/src/` — a folder for a path
  /// ending in `/`, a file with the given source otherwise — and the
  /// inspector's verdict on it.
  DwServerFeatureInspector inspect(Map<String, String> files) {
    writeShared();
    final server = Directory(p.join(sandbox.path, 'my_server'));
    for (final MapEntry(key: path, value: source) in files.entries) {
      final full = p.join(server.path, 'lib', 'src', path);
      if (path.endsWith('/')) {
        Directory(full).createSync(recursive: true);
      } else {
        File(full)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(source);
      }
    }
    final inspector = DwServerFeatureInspector(
      serverPackageDir: server,
      sharedPackageDir: Directory(p.join(sandbox.path, 'my_shared')),
    );
    inspector.run();
    return inspector;
  }

  const declaration = "final chatFeature = DwServerFeature('chat');\n";

  group('the closed file set', () {
    test('every kind, a part, a generated part and logic/ pass', () {
      final inspector = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_rows.dart': '',
        'chat/chat_rows.dw.dart': '',
        'chat/chat_handlers.dart': '',
        'chat/chat_reads_handlers.dart': '',
        'chat/chat_objects.dart': '',
        'chat/chat_publications.dart': '',
        'chat/chat_jobs.dart': '',
        'chat/chat_access.dart': '',
        'chat/logic/amo_client.dart': '',
        'chat/logic/pricing/rules.dart': '',
        'daily_plan/daily_plan_feature.dart':
            "final f = DwServerFeature('daily_plan');",
        'core/push/app_push.dart': '',
        'migrations/rows/whatever.dart': '',
      });
      expect(inspector.fileFindings, isEmpty);
    });

    test('a free name, another feature\'s prefix and a non-Dart file fail', () {
      final findings = inspect({
        'courses/courses_feature.dart': declaration,
        'courses/course_handlers.dart': '',
        'courses/amo_client.dart': '',
        'courses/courses_job_kinds.dart': '',
        'courses/notes.md': '',
      }).fileFindings;
      expect(findings, hasLength(4));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'courses/course_handlers.dart — a feature holds '
            'courses_<kind>.dart or courses_<part>_<kind>.dart',
          ),
          contains('courses/amo_client.dart'),
          contains('courses/courses_job_kinds.dart'),
          contains('courses/notes.md'),
        ]),
      );
    });

    test(
      'a feature declares itself once: no <feature>_<part>_feature.dart',
      () {
        final findings = inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_reads_feature.dart': '',
        }).fileFindings;
        expect(findings, [contains('chat/chat_reads_feature.dart')]);
      },
    );

    test('logic/ is the one subfolder; a layer name says so', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/rows/chat.dart': '',
        'chat/worker/connection.dart': '',
      }).fileFindings;
      expect(findings, hasLength(2));
      expect(
        findings.first,
        contains(
          'chat/rows/ — a feature has one '
          'subfolder, logic/; `rows` is a layer',
        ),
      );
      expect(
        findings.last,
        contains(
          'chat/worker/ — a feature has one '
          'subfolder, logic/; its files go to chat_<kind>.dart',
        ),
      );
    });

    test('logic/ holds no kind-suffixed file, at any depth', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/logic/chat_send_handlers.dart': '',
        'chat/logic/deep/member_access.dart': '',
      }).fileFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/logic/chat_send_handlers.dart — logic/ holds what is '
            'not one of the kinds',
          ),
          contains('chat/logic/deep/member_access.dart'),
        ]),
      );
    });

    test('a layer name is refused at any depth, core/ included', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/logic/domain/rules.dart': '',
        'core/services/mailer.dart': '',
        'core/push/helpers/x.dart': '',
      }).fileFindings;
      expect(findings, hasLength(3));
      expect(
        findings.join('\n'),
        allOf([
          contains('chat/logic/domain/ — `domain` is a layer name'),
          contains('core/services/ — `services` is a layer name'),
          contains('core/push/helpers/ — `helpers` is a layer name'),
        ]),
      );
    });
  });

  group('what a file declares', () {
    test('handlers: in *_handlers.dart pass, elsewhere fail', () {
      const handlers = '''
final chatHandlers = <DwCallHandler>[
  DwCallHandler.command<SendMessage, ChatMessage>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async => throw UnimplementedError(),
  ),
];
''';
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_handlers.dart': handlers,
          'chat/chat_reads_handlers.dart': handlers,
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart':
            "final f = DwServerFeature('chat', handlers: [\n"
            '  DwCallHandler.list<ListMessages, ChatMessage>(),\n]);\n',
        'chat/logic/send.dart': handlers,
        'core/auth.dart': handlers,
      }).codeFindings;
      expect(findings, hasLength(3));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_feature.dart:2 declares handlers — they live in '
            'chat_handlers.dart or chat_<part>_handlers.dart',
          ),
          contains('chat/logic/send.dart:1 declares handlers'),
          contains('core/auth.dart:1 declares handlers — core/ holds none'),
        ]),
      );
    });

    test('rows: in *_rows.dart pass, elsewhere fail', () {
      const row = '''
@DwSqlTable('chat_message')
final class ChatMessageRow extends DwTableRow with _\$ChatMessageRow {}
''';
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_rows.dart': row,
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_objects.dart': row,
        'chat/rows/chat.dart': row,
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.first,
        contains(
          'chat/chat_objects.dart:1 declares row '
          'classes — they live in chat_rows.dart',
        ),
      );
      expect(findings.last, contains('chat/rows/chat.dart:1'));
    });

    test('jobs: in *_jobs.dart pass, elsewhere fail', () {
      const jobs = '''
abstract final class ChatJobs {
  static const remind = DwJobKind<({int id})>('chat.remind');
}
final chatJobs = <DwJobDefinition>[
  DwQueuedJob(ChatJobs.remind, handle: (ctx, payload) async {}),
  DwRecurringJob('chat.sweep', every: Duration(hours: 1)),
];
''';
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_jobs.dart': jobs,
          // Named, not constructed: a command enqueues a kind.
          'chat/chat_handlers.dart':
              'Future<void> f(DwJobKind<int> kind) => ctx.jobs.enqueue(kind);',
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': jobs,
        'core/bootstrap.dart': "final j = DwRecurringJob('x');",
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:2 declares jobs or job kinds — they '
            'live in chat_jobs.dart',
          ),
          contains('core/bootstrap.dart:1 declares jobs'),
        ]),
      );
    });

    test('DwServerFeature: in <feature>_feature.dart pass, elsewhere fail', () {
      expect(
        inspect({'chat/chat_feature.dart': declaration}).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': "final other = DwServerFeature('reads');",
        'core/bootstrap.dart': "final f = DwServerFeature('x');",
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:1 declares a DwServerFeature — a '
            'feature declares itself once, in chat/chat_feature.dart',
          ),
          contains('core/bootstrap.dart:1 declares a DwServerFeature'),
        ]),
      );
    });

    test('publications: a function that publishes passes in '
        '*_publications.dart, and a hook or a handler publishing inline is '
        'not a publication', () {
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_publications.dart': '''
abstract final class ChatPublications {
  static Future<ChatMessage> message(DwCallContext ctx, ChatMessageRow row) async {
    final object = await ChatObjects.message(row);
    ctx
      ..publish(AppChannels.chat, object)
      ..publish(AppChannels.admin, object);
    return object;
  }
}
''',
          'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[
  DwCallHandler.command<SendMessage, ChatMessage>(
    handle: (ctx, command) async {
      if (command.text.isEmpty) {
        ctx.publish(AppChannels.chat, command);
      }
      return x;
    },
  ),
];
''',
          'core/auth.dart': '''
abstract final class AppAuth {
  static DwAuthConfig config() => DwAuthConfig(
    onAccountCreated: (ctx, accountId) async {
      ctx.publish(AppChannels.admin, 'a // not a comment');
    },
    onOther: (ctx) => ctx.publish(AppChannels.admin, 1),
  );
}
''',
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[];

Future<void> _publishRead(DwCallContext ctx, int id) async {
  ctx.publish(AppChannels.chat, id);
}
''',
        'core/publish.dart': '''
abstract final class AppPublish {
  // ctx.publish(x) in a comment is nothing
  static void team(DwCallContext ctx, int id) =>
      ctx.publish(AppChannels.team, id);
}
''',
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:3 declares a publication '
            '(`_publishRead` publishes) — publications live in '
            'chat_publications.dart',
          ),
          contains(
            'core/publish.dart:3 declares a publication (`team` '
            'publishes) — core/ holds none',
          ),
        ]),
      );
    });

    test('mapping: a row → data object function passes in *_objects.dart, '
        'and a publication handing on what another built maps nothing', () {
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_objects.dart': '''
abstract final class ChatObjects {
  static ChatMessage message(ChatMessageRow row) => ChatMessage(id: row.id!);
  static Future<List<PersonCard>> people(List<UserProfileRow> rows) async =>
      [for (final row in rows) PersonCard(id: row.id!)];
}
''',
          'chat/chat_publications.dart': '''
Future<ChatMessage> publishOne(DwCallContext ctx, ChatMessageRow row) async =>
    (await publishMany(ctx, [row])).single;
''',
          // Takes a row, builds a data object — but not a row's mapping:
          // it returns no data object.
          'chat/logic/counts.dart':
              'int countOf(ChatMessageRow row) => ChatMessage(id: 1).id;',
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[];

ChatMessage _toObject(ChatMessageRow row) => ChatMessage(id: row.id!);
''',
        'chat/chat_rows.dart': '''
final class ChatMessageRow extends DwTableRow {
  ChatMessage toObject() => ChatMessage(id: id!);
}
''',
        'chat/logic/cards.dart': '''
extension on UserProfileRow {
  PersonCard get card => PersonCard(id: id!);
}
''',
        'core/objects.dart': '''
abstract final class AppObjects {
  static PersonCard person(UserProfileRow row) => PersonCard(id: row.id!);
}
''',
      }).codeFindings;
      expect(findings, hasLength(4));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:3 maps a row to a data object '
            '(`_toObject`) — mapping lives in chat_objects.dart',
          ),
          contains(
            'chat/chat_rows.dart:2 maps a row to a data object '
            '(`toObject`)',
          ),
          contains(
            'chat/logic/cards.dart:2 maps a row to a data object '
            '(`card`)',
          ),
          contains(
            'core/objects.dart:2 maps a row to a data object (`person`) '
            '— core/ holds none',
          ),
        ]),
      );
    });

    test('names in comments and strings are not declarations', () {
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/logic/notes.dart': r'''
/// DwCallHandler.command<X, Y>( is how a handler starts;
/// @DwSqlTable('x') and DwJobKind<int>('x') too.
const text = 'DwServerFeature(\'chat\') ${"DwQueuedJob("}';
/* extends DwTableRow */
''',
        }).codeFindings,
        isEmpty,
      );
    });
  });

  test('dwServerFeatureFileKind reads the closed set', () {
    expect(dwServerFeatureFileKind('chat', 'chat_rows.dart'), 'rows');
    expect(
      dwServerFeatureFileKind('chat', 'chat_read_state_handlers.dart'),
      'handlers',
    );
    expect(
      dwServerFeatureFileKind('daily_plan', 'daily_plan_jobs.dart'),
      'jobs',
    );
    expect(dwServerFeatureFileKind('chat', 'chat_feature.dart'), 'feature');
    expect(dwServerFeatureFileKind('chat', 'chat_reads_feature.dart'), isNull);
    expect(dwServerFeatureFileKind('chat', 'chat_send.dart'), isNull);
    expect(dwServerFeatureFileKind('chat', 'chats_rows.dart'), isNull);
    expect(dwServerFeatureFileKind('chat', 'chat_Reads_rows.dart'), isNull);
  });
}
