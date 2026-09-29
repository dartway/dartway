import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_ui_rules.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One way to show a read, a spinner, a dialog, a route and a new thing
/// (dartway/dartway#390). Each true positive is paired with the false one a
/// naive text scan produces — a word in a comment, a hook's `.value`, a
/// closure parameter named like the read, a controller in `logic/`.
void main() {
  List<DwCheckType> typesIn(String rel, String source) => [
    for (final finding in DwFlutterUiInspector.judge(rel, source)) finding.type,
  ];

  List<int> linesOf(String rel, String source, DwCheckType type) => [
    for (final finding in DwFlutterUiInspector.judge(rel, source))
      if (finding.type == type) finding.line,
  ];

  group('forbiddenRequestRead', () {
    const read = DwCheckType.forbiddenRequestRead;

    test('a member of a watched read, chained or bound, is refused', () {
      const source = '''
class CoursePage extends HookConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(dw.request(GetCourse(id))).value?.title;
    final course = ref.watch(dw.request(GetCourse(id)));
    if (course.hasError) return const SizedBox();
    return course.when(data: (c) => Text(c.title), loading: () => x, error: (e, s) => y);
  }
}
''';
      expect(linesOf('app/course/course_page.dart', source, read), [3, 5, 6]);
    });

    test('a switch or a case pattern over it is refused, and so is a read '
        'bound to a name first', () {
      const source = '''
Widget build(BuildContext context, WidgetRef ref) {
  final request = dw.request(GetCourse(id));
  final course = ref.watch(request);
  if (course case AsyncError(error: DwRefusalException())) return gone;
  return switch (course) {
    AsyncData(:final value) => Text(value.title),
    _ => const SizedBox(),
  };
}
''';
      expect(linesOf('app/course/course_page.dart', source, read), [4, 5]);
    });

    test('a select of the read is refused; a refetch through its notifier is '
        'not', () {
      const source = '''
Widget build(BuildContext context, WidgetRef ref) {
  final role = ref.watch(dw.request(const GetMyProfile()).select((p) => p.value?.role));
  return Button(onTap: () => ref.read(dw.request(const GetMyProfile()).notifier).refetch());
}
''';
      expect(linesOf('app/profile/profile_page.dart', source, read), [2]);
    });

    test('DwReadBuilder, hooks and a closure parameter named like the read are '
        'not reads taken apart', () {
      const source = '''
Widget build(BuildContext context, WidgetRef ref) {
  final draft = useState('');
  final card = ref.watch(dw.request(GetCard(id)));
  // card.value is what the old code read
  return DwReadBuilder(
    dw.request(GetCard(id)),
    builder: (context, card) => Text(card.title + draft.value),
  );
}
''';
      expect(linesOf('admin/card/card_page.dart', source, read), isEmpty);
    });

    test('a controller in logic/ and wiring in core/ may watch a read', () {
      const source = '''
AsyncValue<Profile?> build(Ref ref) {
  final profile = ref.watch(dw.request(const GetMyProfile()));
  return profile.whenData((p) => p);
}
''';
      expect(
        typesIn('app/profile/logic/profile_controller.dart', source),
        isEmpty,
      );
      expect(typesIn('core/profile/my_profile.dart', source), isEmpty);
      expect(typesIn('app/profile/widgets/profile_view.dart', source), [read]);
    });
  });

  group('forbiddenProgressIndicator', () {
    const spinner = DwCheckType.forbiddenProgressIndicator;
    const source = '''
Widget build(BuildContext context) => Column(children: [
  const CircularProgressIndicator(),
  CircularProgressIndicator.adaptive(),
  const CupertinoActivityIndicator(),
  // CircularProgressIndicator() in a comment is prose
  Text('CircularProgressIndicator()'),
]);
''';

    test('is refused outside ui_kit/, wherever else it stands', () {
      expect(linesOf('app/home/home_page.dart', source, spinner), [2, 3, 4]);
      expect(linesOf('core/profile/signed_in_gate.dart', source, spinner), [
        2,
        3,
        4,
      ]);
    });

    test('is the kit\'s own', () {
      expect(typesIn('ui_kit/theme/app_button.dart', source), isEmpty);
    });
  });

  group('forbiddenNavigationCall', () {
    const nav = DwCheckType.forbiddenNavigationCall;

    test('raw dialogs, sheets, pushes and page routes are refused outside the '
        'kit and the router', () {
      const source = '''
void open(BuildContext context) {
  showDialog<bool>(context: context, builder: (_) => const Text('x'));
  showModalBottomSheet(context: context, builder: (_) => sheet);
  showCupertinoModalPopup(context: context, builder: (_) => sheet);
  Scaffold.of(context).showBottomSheet((_) => sheet);
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  Navigator.push(context, CupertinoPageRoute(builder: (_) => page));
  Navigator.pushNamed(context, 'x');
  context.showAppBottomSheet(child: sheet);
  GoRouter.of(context).goNamed(AppNavigationZone.home.name);
}
''';
      expect(linesOf('app/chat/widgets/chat_menu.dart', source, nav), [
        2,
        3,
        4,
        5,
        6,
        6,
        7,
        7,
        8,
      ]);
      expect(
        typesIn('ui_kit/2_frequent/show_app_bottom_sheet.dart', source),
        isEmpty,
      );
      expect(typesIn('core/router/app_scaffold.dart', source), isEmpty);
    });

    test('one pop spelling, everywhere — the kit included', () {
      const source = '''
void close(BuildContext context) {
  Navigator.of(context).pop(true);
  Navigator.pop(context);
  GoRouter.of(context).pop();
  context.pop();
}
''';
      expect(linesOf('app/news/widgets/sheet.dart', source, nav), [3, 4, 5]);
      expect(linesOf('ui_kit/2_frequent/app_dialog.dart', source, nav), [
        3,
        4,
        5,
      ]);
    });
  });

  group('sentinelId', () {
    const sentinel = DwCheckType.sentinelId;

    test('a route parameter set to 0 or -1, and an id compared with it, are '
        'refused', () {
      const source = '''
void go(BuildContext context, int id, Course course) {
  if (id == 0) return;
  if (course.courseId != -1) return;
  if (0 == course.id) return;
  context.goNamed(AdminNavigationZone.course.name,
      pathParameters: AdminParams.courseId.set(0));
}
''';
      expect(
        linesOf('admin/courses/admin_courses_page.dart', source, sentinel),
        [2, 3, 4, 6],
      );
    });

    test('stand-in data for a skeleton, a count and a real id are not '
        'sentinels', () {
      const source = '''
const placeholder = Course(id: 0, courseId: 0, title: 'Course');
void go(BuildContext context, List<int> ids, int id) {
  if (ids.length == 0) return;
  if (id == 10) return;
  AdminParams.courseId.set(id);
}
''';
      expect(typesIn('core/placeholder_objects.dart', source), isEmpty);
    });
  });

  test('a run over lib/ skips generated files, honours --dir and --type, and '
      'tallies what it found', () {
    final sandbox = Directory.systemTemp.createTempSync('dw_ui_rules');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    void write(String rel, String content) =>
        File(p.join(sandbox.path, 'lib', rel))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
    write(
      'app/home/home_page.dart',
      'final x = const CircularProgressIndicator();\n'
          'void f(BuildContext c) => Navigator.pop(c);\n',
    );
    write(
      'admin/users/users_page.dart',
      'final y = CircularProgressIndicator();',
    );
    write(
      'app/home/home_page.g.dart',
      'final z = CircularProgressIndicator();',
    );

    final tally = DwCheckTally();
    final errors = DwFlutterUiInspector(
      flutterPackageDir: sandbox,
    ).run(tally: tally);
    expect(errors, 3);
    expect(tally.counts, {
      DwCheckType.forbiddenProgressIndicator: 2,
      DwCheckType.forbiddenNavigationCall: 1,
    });

    expect(
      DwFlutterUiInspector(
        flutterPackageDir: sandbox,
        targetDirPath: 'lib/admin',
      ).run(),
      1,
    );
    expect(
      DwFlutterUiInspector(
        flutterPackageDir: sandbox,
        filterType: DwCheckType.forbiddenNavigationCall,
      ).run(),
      1,
    );
  });
}
