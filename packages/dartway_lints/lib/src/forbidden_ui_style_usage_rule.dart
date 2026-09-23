import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'paths.dart';

/// The theme getters the app's `ui_kit/` defines on `BuildContext`. Reaching
/// for them in feature code is how a style escapes the kit.
const _forbiddenContextGetters = {'theme', 'textTheme', 'colorScheme'};

/// DartWay convention: the UI kit is the single source of styles. Raw
/// `Color`/`TextStyle`/`BorderRadius` constructions and direct theme access
/// are only allowed inside `ui_kit/` — feature code composes UI-kit widgets
/// and presets instead.
class ForbiddenUiStyleUsageRule extends AnalysisRule {
  ForbiddenUiStyleUsageRule()
    : super(
        name: 'forbidden_ui_style_usage',
        description: 'Styles and theme access live in ui_kit/ only.',
      );

  static const LintCode code = LintCode(
    'forbidden_ui_style_usage',
    'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be '
        'used outside ui_kit.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = dwPathOf(context);
    if (dwIsUiKitFile(path) || dwIsGeneratedFile(path)) return;
    final visitor = _Visitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addPrefixedIdentifier(this, visitor)
      ..addPropertyAccess(this, visitor)
      ..addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  /// `Color(...)`, `TextStyle(...)`, `BorderRadius(...)`.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'Color' ||
        typeName == 'TextStyle' ||
        typeName == 'BorderRadius') {
      rule.reportAtNode(node);
    }
  }

  /// `Colors.red`, `BorderRadius.circular(8)` — and `context.textTheme`.
  ///
  /// The last one is never a PropertyAccess: when the target is a simple
  /// identifier the analyzer builds a PrefixedIdentifier instead.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix;
    if (prefix.name == 'Colors' || prefix.name == 'BorderRadius') {
      rule.reportAtNode(node);
      return;
    }
    if (_isBuildContext(prefix) &&
        _forbiddenContextGetters.contains(node.identifier.name)) {
      rule.reportAtNode(node);
    }
  }

  /// `this.context.textTheme`, `widget.context.theme` — a target that is not a
  /// plain identifier really does arrive as a PropertyAccess.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target != null &&
        _isBuildContext(target) &&
        _forbiddenContextGetters.contains(node.propertyName.name)) {
      rule.reportAtNode(node);
    }
  }

  /// `Theme.of(context)` — the plainest form of theme access.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (node.methodName.name == 'of' &&
        target is SimpleIdentifier &&
        target.name == 'Theme') {
      rule.reportAtNode(node);
    }
  }

  /// Asks the type system rather than the spelling: a variable named `ctx` is
  /// just as much a `BuildContext` as one named `context`.
  static bool _isBuildContext(Expression expression) =>
      expression.staticType?.getDisplayString() == 'BuildContext';
}
