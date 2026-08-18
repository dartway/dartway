import 'dart:io';

import 'package:dartway_cli/src/checker/dw_feature_tree.dart';
import 'package:dartway_cli/src/checker/dw_unused_feature_files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Dead code inside a feature is the kind the compiler cannot see: nobody
/// outside the feature may import its `widgets/`/`logic/`, so a public class in
/// there is unreachable the moment its own feature stops calling it — and still
/// compiles, still travels through refactors.
///
/// The tests that matter are the two false positives a naive version produces,
/// both taken from real code: a type is not how it is called, and dead code
/// keeps dead code alive.
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
}
