import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_feature_tree.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:dartway_cli/src/checker/dw_unused_feature_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Dead code inside a feature is the kind the compiler cannot see: nobody
/// outside the feature may import its `widgets/`/`logic/`, so a public class in
/// there is unreachable the moment its own feature stops calling it — and still
/// compiles, still travels through refactors.
///
/// The tests that matter are the false positives a naive version produces, all
/// of them taken from real code: a type is not how it is called, a function is
/// a declaration too, a conditional import is one symbol in several files, and
/// dead code keeps dead code alive. Each is paired with the true positive it
/// could have silenced — a check that stops firing is the more expensive way to
/// lose an argument with a false positive.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_unused_feature');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// Writes a feature folder and returns the node the checker would build.
  DwFeatureNode featureWith(Map<String, String> files) {
    final dir = Directory(p.join(sandbox.path, 'my_feature'))
      ..createSync(recursive: true);

    for (final entry in files.entries) {
      final file = File(p.join(dir.path, entry.key));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }

    return buildNode(dir);
  }

  List<String> unusedNames(DwFeatureNode feature) => [
    for (final unused in findUnusedFeatureFiles(feature))
      p.basename(unused.file.path),
  ];

  test('a widget nobody in the feature builds is dead', () {
    final feature = featureWith({
      'my_feature.dart': '''
class MyFeature extends StatelessWidget {
  Widget build(BuildContext context) => const FeatureBody();
}
''',
      'widgets/feature_body.dart': 'class FeatureBody {}',
      'widgets/save_button_bar.dart': 'class SaveButtonBar {}',
    });

    expect(unusedNames(feature), ['save_button_bar.dart']);
  });

  test('an extension is alive through its member, not its type name', () {
    // The trap: `CommentOptions` appears nowhere, so searching for the declared
    // type reports a file that is called on every build.
    final feature = featureWith({
      'my_feature.dart': '''
class MyFeature {
  void build(List<Comment> comments) => comments.commentParentOptions;
}
''',
      'logic/comment_options.dart': '''
extension CommentOptions on List<Comment> {
  List<Comment> get commentParentOptions => this;
}
''',
    });

    expect(unusedNames(feature), isEmpty);
  });

  test('a notifier is alive through its provider variable', () {
    // Same trap, the other common shape: the class name never appears, the
    // provider does.
    final feature = featureWith({
      'my_feature.dart': '''
class MyFeature {
  void build(WidgetRef ref) => ref.watch(chatPostsSearchQueryProvider);
}
''',
      'logic/chat_posts_search_query.dart': '''
final chatPostsSearchQueryProvider =
    NotifierProvider<ChatPostsSearchQuery, String>(ChatPostsSearchQuery.new);

class ChatPostsSearchQuery extends Notifier<String> {
  String build() => '';
}
''',
    });

    expect(unusedNames(feature), isEmpty);
  });

  test('dead code does not keep its own dependency alive', () {
    // One pass sees only the handler: its settings file is referenced — by the
    // handler. The sweep has to repeat.
    final feature = featureWith({
      'my_feature.dart': 'class MyFeature {}',
      'logic/attachment_handler.dart': '''
class AttachmentHandler {
  final settings = const AttachmentSettings();
}
''',
      'logic/attachment_settings.dart':
          'class AttachmentSettings { const AttachmentSettings(); }',
    });

    expect(unusedNames(feature)..sort(), [
      'attachment_handler.dart',
      'attachment_settings.dart',
    ]);
  });

  test('a name that only appears in a comment or a string is not a use', () {
    final feature = featureWith({
      'my_feature.dart': '''
// Replaced by the settings wrapper — see SaveButtonBar for what it used to do.
class MyFeature {
  final label = 'SaveButtonBar';
}
''',
      'widgets/save_button_bar.dart': 'class SaveButtonBar {}',
    });

    expect(unusedNames(feature), ['save_button_bar.dart']);
  });

  test('a feature with no internals reports nothing', () {
    final feature = featureWith({'my_feature.dart': 'class MyFeature {}'});

    expect(findUnusedFeatureFiles(feature), isEmpty);
  });

  test('one internal file may keep another alive', () {
    final feature = featureWith({
      'my_feature.dart': 'class MyFeature { final body = FeatureBody(); }',
      'widgets/feature_body.dart':
          'class FeatureBody { final row = FeatureRow(); }',
      'widgets/feature_row.dart': 'class FeatureRow {}',
    });

    expect(unusedNames(feature), isEmpty);
  });

  group('a function is a declaration too', () {
    // The index read classes, enums and top-level variables and missed
    // functions — while the `final` lines *inside* a function body indexed as
    // if they were top-level. A file whose only public member was a function
    // was therefore judged on the names of its own locals, which appear
    // nowhere else by definition, and buried alive.
    test('a top-level function called from the entry point is alive', () {
      final feature = featureWith({
        'my_feature.dart': '''
class MyFeature {
  String label(Duration value) => formatDuration(value);
}
''',
        'logic/format_duration.dart': '''
String formatDuration(Duration value) {
  final rounded = value.inMinutes;
  return '\$rounded min';
}
''',
      });

      expect(unusedNames(feature), isEmpty);
    });

    test('a top-level getter is alive through its own name', () {
      final feature = featureWith({
        'my_feature.dart': '''
class MyFeature {
  String get title => logPrefix;
}
''',
        'logic/log_prefix.dart': '''
String get logPrefix {
  final stamp = DateTime.now().toIso8601String();
  return '[\$stamp]';
}
''',
      });

      expect(unusedNames(feature), isEmpty);
    });

    // The other half of the same rule, and the half worth guarding: indexing a
    // function must not turn into never reporting one.
    test('a top-level function nobody calls is still dead', () {
      final feature = featureWith({
        'my_feature.dart': 'class MyFeature {}',
        'logic/format_duration.dart': '''
String formatDuration(Duration value) {
  final rounded = value.inMinutes;
  return '\$rounded min';
}
''',
      });

      expect(unusedNames(feature), ['format_duration.dart']);
    });
  });

  group('a conditional import is one symbol in several files', () {
    // `foo.dart` + `foo_stub.dart` + `foo_web.dart`: the forwarder declares
    // nothing, and each half is a platform the other build never compiles.
    // Read one file at a time the trio has no visible caller.
    const forwarder = '''
export 'download_file_stub.dart'
    if (dart.library.js_interop) 'download_file_web.dart';
''';
    const stub = '''
void downloadFile(String name) => throw UnsupportedError('web only');
''';
    const web = '''
void downloadFile(String name) {
  final anchor = Anchor(name);
  anchor.click();
}
''';

    test('the trio is alive when its symbol is used', () {
      final feature = featureWith({
        'my_feature.dart': '''
import 'logic/download_file.dart';

class MyFeature {
  void onTap() => downloadFile('report.csv');
}
''',
        'logic/download_file.dart': forwarder,
        'logic/download_file_stub.dart': stub,
        'logic/download_file_web.dart': web,
      });

      expect(unusedNames(feature), isEmpty);
    });

    // The true positive, and the proof that the link is followed at all: the
    // forwarder declares nothing, so on its own it was never even a candidate
    // — a dead trio was reported as a dead half.
    test('a trio nobody uses is reported in full, the forwarder too', () {
      final feature = featureWith({
        'my_feature.dart': 'class MyFeature {}',
        'logic/download_file.dart': forwarder,
        'logic/download_file_stub.dart': stub,
        'logic/download_file_web.dart': web,
      });

      expect(unusedNames(feature)..sort(), [
        'download_file.dart',
        'download_file_stub.dart',
        'download_file_web.dart',
      ]);
    });
  });

  group('the finding names where the file should go instead', () {
    // "Dead code" is only half an answer: a file the feature stopped using is
    // often a file somebody else needs, and the message said nothing about
    // where that somebody may reach it from. The intended shape was learned by
    // moving the file until the rule stopped firing — which for a platform
    // trio meant discovering `lib/core/platform/` by elimination.
    test('the message names the homes outside the feature', () async {
      final package = Directory.systemTemp.createTempSync('dw_unused_message');
      addTearDown(() => package.deleteSync(recursive: true));

      File(p.join(package.path, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('name: sandbox_flutter\n');

      File(p.join(package.path, 'lib', 'app', 'thing', 'thing.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
class ThingPage extends StatelessWidget implements DwFeature {
  DwFeatureSpec get dwFeature => const DwFeatureSpec(id: 'thing');
}
''');

      File(
          p.join(
            package.path,
            'lib',
            'app',
            'thing',
            'widgets',
            'save_bar.dart',
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync('class SaveBar {}');

      final inspector = DwFlutterInspector(
        packageDir: package,
        filterType: DwCheckType.unusedFeatureFile,
      );
      await inspector.run();

      expect(inspector.findingTypes, contains(DwCheckType.unusedFeatureFile));
      final message = inspector.findingMessages.single;
      expect(message, contains('lib/shared/'));
      expect(message, contains('lib/core/'));
      expect(message, contains('lib/core/platform/'));
    });
  });
}
