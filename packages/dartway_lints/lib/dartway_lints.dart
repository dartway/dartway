import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _DartwayLintsPlugin();

class _DartwayLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        ForbiddenColorUsageRule(),
      ];
}

class ForbiddenColorUsageRule extends DartLintRule {
  const ForbiddenColorUsageRule() : super(code: _code);

  static const _code = LintCode(
    name: 'forbidden_ui_style_usage',
    problemMessage:
        'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be used outside ui_kit.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path.replaceAll('\\', '/');

    if (path.contains('/ui_kit/')) return;

    // 1️⃣ Constructor usage
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.toSource();

      if (typeName == 'Color' ||
          typeName == 'TextStyle' ||
          typeName == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    // 2️⃣ Static usage: Colors.red / BorderRadius.circular
    context.registry.addPrefixedIdentifier((node) {
      final prefix = node.prefix.name;

      if (prefix == 'Colors' || prefix == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    // 3️⃣ context.textTheme / colorTheme / colorScheme
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

// PluginBase createPlugin() => _DartwayLintsPlugin();

// class _DartwayLintsPlugin extends PluginBase {
//   @override
//   List<LintRule> getLintRules(CustomLintConfigs configs) => const [
//         ForbiddenColorUsageRule(),
//       ];
// }

// class ForbiddenColorUsageRule extends DartLintRule {
//   const ForbiddenColorUsageRule() : super(code: _code);

//   static const _code = LintCode(
//     name: 'forbidden_ui_style_usage',
//     problemMessage:
//         'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be used outside ui_kit.',
//     errorSeverity: ErrorSeverity.WARNING,
//   );

//   @override
//   void run(
//     CustomLintResolver resolver,
//     ErrorReporter reporter,
//     CustomLintContext context,
//   ) {
//     final filePath = resolver.path.replaceAll('\\', '/');

//     // Разрешаем всё внутри ui_kit
//     if (filePath.contains('/ui_kit/')) return;

//     /// 1️⃣ Color(), TextStyle(), BorderRadius()
//     context.registry.addInstanceCreationExpression((node) {
//       final type = node.constructorName.type;

//       final name = type.name.lexeme;

//       if (name == 'Color' ||
//           name == 'TextStyle' ||
//           name == 'BorderRadius') {
//         reporter.reportErrorForNode(code, node);
//       }
//     });

//     /// 2️⃣ Colors.red / BorderRadius.circular
//     context.registry.addPrefixedIdentifier((node) {
//       final prefix = node.prefix.name;

//       if (prefix == 'Colors' || prefix == 'BorderRadius') {
//         reporter.reportErrorForNode(code, node);
//       }
//     });

//     /// 3️⃣ context.textTheme / colorTheme / colorScheme
//     context.registry.addPropertyAccess((node) {
//       final target = node.target;
//       final property = node.propertyName.name;

//       if (target is SimpleIdentifier &&
//           target.name == 'context' &&
//           (property == 'textTheme' ||
//               property == 'colorTheme' ||
//               property == 'colorScheme')) {
//         reporter.reportErrorForNode(code, node);
//       }
//     });
//   }
// }

// import 'package:analyzer/error/error.dart' hide LintCode;
// import 'package:analyzer/error/listener.dart';
// import 'package:custom_lint_builder/custom_lint_builder.dart';

// PluginBase createPlugin() => _DartwayLintsPlugin();

// class _DartwayLintsPlugin extends PluginBase {
//   @override
//   List<LintRule> getLintRules(CustomLintConfigs configs) => [
//         const ForbiddenColorUsageRule(),
//       ];
// }

// class ForbiddenColorUsageRule extends DartLintRule {
//   const ForbiddenColorUsageRule() : super(code: _code);

//   static const _code = LintCode(
//     name: 'forbidden_ui_style_usage',
//     problemMessage:
//         'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be used outside ui_kit.',
//     errorSeverity: ErrorSeverity.WARNING,
//   );

//   @override
//   void run(
//     CustomLintResolver resolver,
//     ErrorReporter reporter,
//     CustomLintContext context,
//   ) {
//     final path = resolver.path.replaceAll('\\', '/');
//     if (path.contains('/ui_kit/')) return;

//     // 1️⃣ Constructor usage: Color(), TextStyle(), BorderRadius()
//     context.registry.addInstanceCreationExpression((node) {
//       final type = node.constructorName.type;

//       final name = type.name.lexeme;

//       if (name == 'Color' || name == 'TextStyle' || name == 'BorderRadius') {
//         reporter.atNode(node, code);
//       }
//     });

//     // 2️⃣ Static usage: Colors.red, BorderRadius.circular
//     context.registry.addPrefixedIdentifier((node) {
//       final prefix = node.prefix.name;

//       if (prefix == 'Colors' || prefix == 'BorderRadius') {
//         reporter.atNode(node, code);
//       }
//     });

//     // 3️⃣ context.textTheme / context.colorTheme / context.colorScheme
//     context.registry.addPropertyAccess((node) {
//       final target = node.target;
//       final property = node.propertyName.name;

//       if (target == null) return;

//       if (target.toSource() == 'context') {
//         if (property == 'textTheme' ||
//             property == 'colorTheme' ||
//             property == 'colorScheme') {
//           reporter.atNode(node, code);
//         }
//       }
//     });
//   }
// }

// import 'dart:async';
// import 'dart:isolate';

// import 'package:analyzer/dart/analysis/analysis_context.dart';
// import 'package:analyzer/dart/ast/ast.dart';
// import 'package:analyzer/dart/ast/visitor.dart';
// import 'package:analyzer/error/error.dart' hide LintCode;
// import 'package:analyzer/error/listener.dart';
// import 'package:analyzer_plugin/plugin/plugin.dart';
// import 'package:analyzer_plugin/protocol/protocol_common.dart' hide AnalysisError;
// import 'package:analyzer_plugin/protocol/protocol_generated.dart';
// import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

// void main(List<String> args, SendPort sendPort) {
//   AnalyzerPluginStarter(DartwayLintsPlugin()).start(sendPort);
// }

// class DartwayLintsPlugin extends ServerPlugin {
//   DartwayLintsPlugin();

//   @override
//   String get name => 'dartway_lints';

//   @override
//   String get version => '1.0.0';

//   @override
//   Future<void> analyzeFile({
//     required AnalysisContext context,
//     required String path,
//   }) async {
//     if (path.contains('/ui_kit/')) return;

//     final resolvedUnit = await context.currentSession.getResolvedUnit(path);
//     if (resolvedUnit is! ResolvedUnitResult) return;

//     final unit = resolvedUnit.unit;

//     final visitor = _Visitor(
//       path: path,
//       addError: (node) {
//         final error = AnalysisError(
//           AnalysisErrorSeverity.WARNING,
//           AnalysisErrorType.LINT,
//           node.offset,
//           node.length,
//           'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be used outside ui_kit.',
//           'forbidden_ui_style_usage',
//         );

//         context.reportErrors(path, [error]);
//       },
//     );

//     unit.accept(visitor);
//   }
// }

// class _Visitor extends RecursiveAstVisitor<void> {
//   final String path;
//   final void Function(AstNode node) addError;

//   _Visitor({
//     required this.path,
//     required this.addError,
//   });

//   @override
//   void visitInstanceCreationExpression(InstanceCreationExpression node) {
//     final name = node.constructorName.type.name.lexeme;

//     if (name == 'Color' || name == 'TextStyle' || name == 'BorderRadius') {
//       addError(node);
//     }

//     super.visitInstanceCreationExpression(node);
//   }

//   @override
//   void visitPrefixedIdentifier(PrefixedIdentifier node) {
//     final prefix = node.prefix.name;

//     if (prefix == 'Colors' || prefix == 'BorderRadius') {
//       addError(node);
//     }

//     super.visitPrefixedIdentifier(node);
//   }

//   @override
//   void visitPropertyAccess(PropertyAccess node) {
//     final target = node.target;
//     final property = node.propertyName.name;

//     if (target != null && target.toSource() == 'context') {
//       if (property == 'textTheme' ||
//           property == 'colorTheme' ||
//           property == 'colorScheme') {
//         addError(node);
//       }
//     }

//     super.visitPropertyAccess(node);
//   }
// }
