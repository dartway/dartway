import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/deep_relative_import_rule.dart';
import 'src/forbidden_provider_scope_rule.dart';
import 'src/forbidden_ui_style_usage_rule.dart';

/// The analyzer plugin: `plugins: dartway_lints:` in `analysis_options.yaml`.
///
/// The analysis server loads it on its own, so a project neither depends on
/// this package nor runs anything for it — the rules show in the IDE, in
/// `dart analyze` and in `flutter analyze` alike.
final plugin = DartwayLintsPlugin();

class DartwayLintsPlugin extends Plugin {
  @override
  String get name => 'dartway_lints';

  /// Warning rules: on by default, since a project that enables the plugin
  /// asked for DartWay's conventions, not for a menu of them.
  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(ForbiddenUiStyleUsageRule())
      ..registerWarningRule(DeepRelativeImportRule())
      ..registerWarningRule(ForbiddenProviderScopeRule());
  }
}
