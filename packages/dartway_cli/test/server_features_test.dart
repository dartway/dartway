import 'dart:async';
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
        'chat/chat_routes.dart': '',
        'chat/chat_webhook_routes.dart': '',
        'chat/logic/amo_client.dart': '',
        'chat/logic/pricing_rules.dart': '',
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
        'courses/course_file_access.dart': '',
        'courses/token_handlers.dart': '',
        'courses/notes.md': '',
      }).fileFindings;
      expect(findings, hasLength(6));
      // Each names the fix, spelled out: the name it should have, or the
      // logic/ file it is — never a place it would fail again.
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'courses/course_handlers.dart — not courses_<kind>.dart or '
            'courses_<part>_<kind>.dart',
          ),
          contains('rename it to courses_handlers.dart'),
          contains(
            'courses/amo_client.dart — not courses_<kind>.dart or '
            'courses_<part>_<kind>.dart (kind one of feature, rows, handlers, '
            'objects, publications, jobs, access, routes, changes, a part '
            'never a kind): move it to courses/logic/amo_client.dart',
          ),
          contains('courses/courses_job_kinds.dart'),
          contains(
            'rename it to courses_file_access.dart; if it holds no access, it '
            'is logic: courses/logic/file.dart',
          ),
          contains('rename it to courses_token_handlers.dart'),
          contains('courses/notes.md — '),
          contains('a feature holds Dart files only'),
        ]),
      );
    });

    test('a part is never a kind\'s name', () {
      final findings = inspect({
        'orders/orders_feature.dart': declaration,
        'orders/orders_refunds_handlers.dart': '',
        'orders/orders_jobs_handlers.dart': '',
      }).fileFindings;
      expect(findings, [
        allOf(
          contains('orders/orders_jobs_handlers.dart'),
          contains('rename it to orders_handlers.dart'),
        ),
      ]);
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

    test('logic/ holds no kind-suffixed file', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/logic/chat_send_handlers.dart': '',
        'chat/logic/member_access.dart': '',
        'chat/logic/stripe_routes.dart': '',
      }).fileFindings;
      expect(findings, hasLength(3));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/logic/chat_send_handlers.dart — logic/ holds what is '
            'not one of the kinds, and its names carry no kind\'s suffix: '
            'move it beside the feature\'s others as chat_send_handlers.dart; '
            'if it holds no handlers, it is logic: chat/logic/send.dart',
          ),
          contains('chat/logic/member_access.dart'),
          contains('chat/logic/stripe_routes.dart'),
        ]),
      );
    });

    test('logic/ is flat: a folder inside it is a feature too big', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/logic/activity/score.dart': '',
      }).fileFindings;
      expect(findings, [
        contains(
          'chat/logic/activity/ — logic/ is flat; logic that needs grouping '
          'means the feature is too big — split it into features, or into '
          'chat_<part>_<kind>.dart files',
        ),
      ]);
    });

    test('a layer name is refused at any depth, core/ included', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/logic/domain/': '',
        'core/services/mailer.dart': '',
        'core/push/helpers/x.dart': '',
      }).fileFindings;
      expect(findings, hasLength(3));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/logic/domain/ — logic/ is flat, and `domain` is a '
            'layer name',
          ),
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

    test('routes: in *_routes.dart pass, elsewhere fail', () {
      const routes = '''
final githubRoutes = <DwHttpRoute>[
  DwHttpRoute.post('/webhooks/github', (ctx, request) async => x),
];
''';
      expect(
        inspect({
          'github/github_feature.dart': "final f = DwServerFeature('github');",
          'github/github_routes.dart': routes,
          'github/github_webhook_routes.dart': routes,
          // Named, not constructed.
          'github/github_handlers.dart': 'void f(DwHttpRoute route) {}',
        }).codeFindings,
        isEmpty,
      );
      sandbox.deleteSync(recursive: true);
      sandbox.createSync();
      final findings = inspect({
        'github/github_feature.dart':
            "final f = DwServerFeature('github', routes: [\n"
            "  DwHttpRoute.get('/x', handle),\n]);\n",
        'github/github_handlers.dart': routes,
        'core/doors.dart': routes,
      }).codeFindings;
      expect(findings, hasLength(3));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'github/github_feature.dart:2 declares routes (DwHttpRoute) — '
            'they live in github_routes.dart or github_<part>_routes.dart',
          ),
          contains('github/github_handlers.dart:1 declares routes'),
          contains(
            'core/doors.dart:1 declares routes (DwHttpRoute) — core/ '
            'holds none',
          ),
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

  group('what the rules cannot be dodged by', () {
    test('a function rewritten as a closure field is still a declaration', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[];

final toObject = (ChatMessageRow row) => ChatMessage(id: row.id!);
''',
        'core/publish.dart': '''
abstract final class AppPublish {
  static final announce = (DwCallContext ctx, ChatMessageRow row) async {
    ctx.publish(AppChannels.chat, row.id);
  };
}
''',
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:3 maps a row to a data object '
            '(`toObject`)',
          ),
          contains(
            'core/publish.dart:2 declares a publication (`announce` '
            'publishes)',
          ),
        ]),
      );
    });

    test('a closure field in its own kind file passes', () {
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_objects.dart':
              'final toObject = (ChatMessageRow row) => ChatMessage(id: 1);',
          'chat/chat_publications.dart':
              'final announce = (DwCallContext ctx) => ctx.publish(a, b);',
        }).codeFindings,
        isEmpty,
      );
    });

    test('a publish inside a closure a named helper runs is the helper\'s', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[];

// A static of the project's own type named `publish` is not a publish.
Future<void> share(DwCallContext ctx) => PostPublisher.publish(ctx, 1);

void _publishAll(DwCallContext ctx, List<int> ids) =>
    ids.forEach((id) => ctx.publish(AppChannels.chat, id));
''',
        'chat/logic/sync.dart': '''
Future<void> sync(DwCallContext ctx) async {
  await ctx.db.transaction((tx) async {
    ctx.publish(AppChannels.chat, 1);
  });
}
''',
      }).codeFindings;
      expect(findings, hasLength(2));
      expect(
        findings.join('\n'),
        allOf([
          contains(
            'chat/chat_handlers.dart:6 declares a publication '
            '(`_publishAll` publishes)',
          ),
          contains(
            'chat/logic/sync.dart:1 declares a publication (`sync` '
            'publishes)',
          ),
        ]),
      );
    });

    test('a hook handed to a constructor by name stays the hook\'s, even '
        'inside a named method — the skeleton\'s core/auth.dart', () {
      expect(
        inspect({
          'chat/chat_feature.dart': '''
final chatFeature = DwServerFeature(
  'chat',
  channels: [
    DwChannelRule.keyed<int>(
      AppChannel.chat,
      canSubscribe: (ctx, id) async => ctx.publish(a, id),
    ),
  ],
);
''',
          'core/auth.dart': '''
abstract final class AppAuth {
  static DwAuthConfig config({Duration delay = const Duration()}) =>
      DwAuthConfig(
        onAccountCreated: (ctx, accountId) async {
          ctx.publish(AppChannels.admin, accountId);
        },
      );
}
''',
        }).codeFindings,
        isEmpty,
      );
    });

    test('a record return type is read', () {
      final findings = inspect({
        'chat/chat_feature.dart': declaration,
        'chat/chat_handlers.dart': '''
final chatHandlers = <DwCallHandler>[];

(ChatMessage, int) _pair(ChatMessageRow row) => (ChatMessage(id: 1), 1);
''',
      }).codeFindings;
      expect(findings, [
        contains(
          'chat/chat_handlers.dart:3 maps a row to a data object (`_pair`)',
        ),
      ]);
    });

    test('generated parts are not judged', () {
      expect(
        inspect({
          'chat/chat_feature.dart': declaration,
          'chat/chat_objects.dw.dart': '''
@DwSqlTable('x')
final class XRow extends DwTableRow {}
final h = <DwCallHandler>[DwCallHandler.command<A, B>()];
''',
        }).codeFindings,
        isEmpty,
      );
    });
  });

  test('without a shared package, mapping says it was not checked', () {
    final server = Directory(p.join(sandbox.path, 'lone_server'));
    File(p.join(server.path, 'lib', 'src', 'chat', 'chat_handlers.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'ChatMessage f(ChatMessageRow r) => ChatMessage(id: 1);',
      );
    final lines = <String>[];
    runZoned(
      () => DwServerFeatureInspector(serverPackageDir: server).run(),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(
      lines.join('\n'),
      contains('mapping not checked: no shared package found'),
    );
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
    expect(dwServerFeatureFileKind('mcp', 'mcp_routes.dart'), 'routes');
    expect(dwServerFeatureFileKind('chat', 'chat_reads_feature.dart'), isNull);
    expect(dwServerFeatureFileKind('chat', 'chat_send.dart'), isNull);
    expect(
      dwServerFeatureFileKind('orders', 'orders_jobs_handlers.dart'),
      isNull,
    );
    expect(dwServerFeatureFileKind('chat', 'chats_rows.dart'), isNull);
    expect(dwServerFeatureFileKind('chat', 'chat_Reads_rows.dart'), isNull);
  });
}
