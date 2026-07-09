import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _DartwayLintsPlugin();

class _DartwayLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    ForbiddenUiStyleUsageRule(),
  ];
}

bool _isUiKitFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').contains('ui_kit');
}

/// DartWay convention: the UI kit is the single source of styles. Raw
/// `Color`/`TextStyle`/`BorderRadius` constructions and direct theme access
/// are only allowed inside `ui_kit/` — feature code composes UI-kit widgets
/// and presets instead.
class ForbiddenUiStyleUsageRule extends DartLintRule {
  const ForbiddenUiStyleUsageRule() : super(code: _code);

  static const _code = LintCode(
    name: 'forbidden_ui_style_usage',
    problemMessage:
        'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be used outside ui_kit.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;

    if (_isUiKitFile(path)) return;

    // Color(), TextStyle(), BorderRadius()
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Color' ||
          typeName == 'TextStyle' ||
          typeName == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    // Colors.red / BorderRadius.circular
    context.registry.addPrefixedIdentifier((node) {
      final prefix = node.prefix.name;

      if (prefix == 'Colors' || prefix == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    // context.textTheme / colorTheme / colorScheme
    context.registry.addPropertyAccess((node) {
      final target = node.target;
      final property = node.propertyName.name;

      if (target != null &&
          target.toSource() == 'context' &&
          (property == 'textTheme' ||
              property == 'colorTheme' ||
              property == 'colorScheme')) {
        reporter.atNode(node, code);
      }
    });
  }
}
