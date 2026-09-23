import 'package:analyzer/analysis_rule/rule_context.dart';

/// The path of the file being analyzed, relative to its package's root, with
/// forward slashes.
///
/// Relative, because the checks below read folder names — `test`, `ui_kit` —
/// and an absolute path carries the names of every folder above the project
/// too: a project checked out under `~/test/` was exempt from
/// `forbidden_provider_scope` in every file it had.
String dwPathOf(RuleContext context) {
  final path = (context.currentUnit ?? context.definingUnit).file.path;
  final root = context.package?.root.path;
  final relative = root != null && path.startsWith(root)
      ? path.substring(root.length)
      : path;
  return relative.replaceAll('\\', '/').replaceFirst(RegExp('^/'), '');
}

bool dwIsUiKitFile(String path) => path.split('/').contains('ui_kit');

/// Generated code is not written by anyone, so there is no one to tell.
bool dwIsGeneratedFile(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gen.dart') ||
    path.endsWith('.dw.dart');

/// Tests are the one place a `ProviderScope` is written by hand: a widget test
/// builds its own root scope with `overrides:`, and nothing outside the tree it
/// just pumped reads through a provider's `Ref`.
bool dwIsTestFile(String path) {
  final segments = path.split('/');
  return segments.last.endsWith('_test.dart') ||
      segments.contains('test') ||
      segments.contains('integration_test');
}
