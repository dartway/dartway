import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_unbounded_read.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `unboundedRead`: a request handler reading every row its filter matches
/// (dartway/dartway#644).
void main() {
  List<int> lines(String source) => [
    for (final read in DwUnboundedReadInspector.unboundedReadsIn(source))
      read.line,
  ];

  group('flags', () {
    test('a list handler reading without a limit', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListTasks, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.tasks.find(
        where: (t) => t.projectId.equals(request.projectId),
        orderBy: (t) => [t.id.asc()],
      ))
        TaskObjects.task(row),
    ],
  ),
];
'''),
        [5],
      );
    });

    test('every request kind, and a find with no arguments', () {
      final reads = DwUnboundedReadInspector.unboundedReadsIn('''
final handlers = <DwCallHandler>[
  DwCallHandler.single<GetBoard, Board>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final columns = await ctx.db.columns.find();
      return Board(columns.length);
    },
  ),
  DwCallHandler.table<ListMembers, Member>(
    access: DwAccessRule.signedIn,
    rows: (ctx, request, table) async {
      final teams = await ctx.db.teams.find(where: (t) => t.open.isTrue());
      return [];
    },
    count: (ctx, request) => ctx.db.members.count(),
  ),
];
''');
      expect(reads, [(line: 5, kind: 'single'), (line: 12, kind: 'table')]);
    });

    test('a limit inside a nested call is not the read\'s own', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListTasks, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => await ctx.db.tasks.find(
      where: (t) => t.id.inList(ids(limit: 3)),
    ),
  ),
];
'''),
        [4],
      );
    });
  });

  group('passes over', () {
    test('a read with a limit, or with the reason it stays small', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListTasks, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => await ctx.db.tasks.find(
      orderBy: (t) => [t.id.asc()],
      limit: request.fetchLimit,
    ),
  ),
  DwCallHandler.list<ListColumns, Column>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => await ctx.db.columns.find(
      unbounded: 'a board has a handful of columns',
    ),
  ),
  DwCallHandler.page<ListNews, News>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request, page) async => await ctx.db.news.find(
      limit: page.fetchLimit,
      offset: page.offset,
    ),
  ),
];
'''),
        isEmpty,
      );
    });

    test('a command, and reads by id', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.command<NotifyAll, void>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final members = await ctx.db.members.find();
    },
  ),
  DwCallHandler.single<GetTask, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async {
      final row = await ctx.db.tasks.findById(request.id);
      final first = await ctx.db.tasks.findFirst(where: (t) => t.open);
      final some = await ctx.db.tasks.findByIds(request.ids);
      return row;
    },
  ),
];
'''),
        isEmpty,
      );
    });

    test('a read in a comment or a string', () {
      expect(
        lines('''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListTasks, Task>(
    access: DwAccessRule.signedIn,
    // Was `ctx.db.tasks.find()` before it was paged.
    handle: (ctx, request) async => explain('ctx.db.tasks.find()'),
  ),
];
'''),
        isEmpty,
      );
    });
  });

  test('run reads only *_handlers.dart, and warns without failing', () {
    final root = Directory.systemTemp.createTempSync('unbounded_read_');
    addTearDown(() => root.deleteSync(recursive: true));
    final server = Directory(p.join(root.path, 'acme_server'));
    const read = '''
final handlers = <DwCallHandler>[
  DwCallHandler.list<ListTasks, Task>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => await ctx.db.tasks.find(),
  ),
];
''';
    File(p.join(server.path, 'lib', 'src', 'tasks', 'tasks_handlers.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(read);
    File(p.join(server.path, 'lib', 'src', 'tasks', 'tasks_jobs.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(read);

    final tally = DwCheckTally();
    final inspector = DwUnboundedReadInspector(serverPackageDir: server);
    expect(inspector.run(tally: tally), 0);
    expect(inspector.findings, [
      contains('acme_server/lib/src/tasks/tasks_handlers.dart:4'),
    ]);
    expect(inspector.findings.single, contains('request.fetchLimit'));
    expect(DwCheckType.unboundedRead.severity, DwCheckSeverity.warning);
  });
}
