import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _DartwayLintsPlugin();

class _DartwayLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    ForbiddenUiStyleUsageRule(),
    // ForbiddenUiKitImportRule(),
    // ForbiddenFeatureImportRule(),
  ];
}

bool _isUiKitFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').contains('ui_kit');
}

////////////////////////////////////////////////////////////////
/// RULE 1
/// forbidden_ui_style_usage
////////////////////////////////////////////////////////////////

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

    /// Color(), TextStyle(), BorderRadius()
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Color' ||
          typeName == 'TextStyle' ||
          typeName == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    /// Colors.red / BorderRadius.circular
    context.registry.addPrefixedIdentifier((node) {
      final prefix = node.prefix.name;

      if (prefix == 'Colors' || prefix == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    /// context.textTheme / colorTheme / colorScheme
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

////////////////////////////////////////////////////////////////
/// RULE 2
/// forbidden_ui_kit_import
////////////////////////////////////////////////////////////////

// class ForbiddenUiKitImportRule extends DartLintRule {
//   const ForbiddenUiKitImportRule() : super(code: _code);

//   static const _code = LintCode(
//     name: 'forbidden_ui_kit_import',
//     problemMessage:
//         'Import ui_kit only via ui_kit.dart. Direct imports are forbidden.',
//     errorSeverity: DiagnosticSeverity.WARNING,
//   );

//   @override
//   void run(
//     CustomLintResolver resolver,
//     DiagnosticReporter reporter,
//     CustomLintContext context,
//   ) {
//     final path = resolver.path;

//     if (_isUiKitFile(path)) return;

//     context.registry.addImportDirective((node) {
//       final uri = node.uri.stringValue;

//       if (uri == null) return;

//       if (uri.contains('/ui_kit/') && !uri.endsWith('ui_kit.dart')) {
//         reporter.atNode(node, code);
//       }
//     });
//   }
// }

////////////////////////////////////////////////////////////////
/// RULE 3
/// forbidden_feature_import
////////////////////////////////////////////////////////////////

// class ForbiddenFeatureImportRule extends DartLintRule {
//   const ForbiddenFeatureImportRule() : super(code: _code);

//   static const _code = LintCode(
//     name: 'forbidden_feature_import',
//     problemMessage:
//         'Features must not import widgets or logic from other features.',
//     errorSeverity: DiagnosticSeverity.WARNING,
//   );

//   @override
//   void run(
//     CustomLintResolver resolver,
//     DiagnosticReporter reporter,
//     CustomLintContext context,
//   ) {
//     final path = resolver.path.replaceAll('\\', '/');
//     final parts = path.split('/');

//     int featureIndex = -1;

//     final widgetsIndex = parts.lastIndexOf('widgets');
//     final logicIndex = parts.lastIndexOf('logic');

//     if (widgetsIndex > 0) featureIndex = widgetsIndex - 1;
//     if (logicIndex > 0) featureIndex = logicIndex - 1;

//     if (featureIndex < 0) return;

//     final currentFeature = parts[featureIndex];

//     context.registry.addImportDirective((node) {
//       final uri = node.uri.stringValue;
//       if (uri == null) return;

//       /// ---- RELATIVE IMPORT ----
//       final relativeMatch = RegExp(
//         r"\.\./([^/]+)/(widgets|logic)/",
//       ).firstMatch(uri);

//       if (relativeMatch != null) {
//         final targetFeature = relativeMatch.group(1);

//         if (targetFeature != currentFeature) {
//           reporter.atNode(node, code);
//         }

//         return;
//       }

//       /// ---- PACKAGE IMPORT ----
//       final packageMatch = RegExp(
//         r"/(app|auth|common|admin)/([^/]+)/(widgets|logic)/",
//       ).firstMatch(uri);

//       if (packageMatch != null) {
//         final targetFeature = packageMatch.group(2);

//         if (targetFeature != currentFeature) {
//           reporter.atNode(node, code);
//         }
//       }
//     });
//   }
// }
