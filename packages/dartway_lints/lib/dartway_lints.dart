/// DartWay's convention rules, as an analyzer plugin.
///
/// Enable them in a package's `analysis_options.yaml`:
///
/// ```yaml
/// plugins:
///   dartway_lints: ^0.4.0
/// ```
///
/// The analysis server loads the plugin from `lib/main.dart`; this library
/// exports the rules for whoever wants to test or compose them.
library;

export 'main.dart' show DartwayLintsPlugin;
export 'src/deep_relative_import_rule.dart';
export 'src/forbidden_provider_scope_rule.dart';
export 'src/forbidden_ui_style_usage_rule.dart';
