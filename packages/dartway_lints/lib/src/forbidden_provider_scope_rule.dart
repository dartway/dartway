import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'paths.dart';

/// DartWay convention: the application never writes a `ProviderScope`. The only
/// one belongs to `DwAppRunner`, which creates it around the whole app; tests
/// build their own.
///
/// A nested scope *looks* like it works, which is exactly why it needs a rule.
/// Widgets under it do read the override — a `WidgetRef` resolves from the
/// nearest scope above its widget. But a provider that reads the same provider
/// through its own `Ref` resolves from the container hosting **it**, which for
/// anything declaring no `dependencies` is the root, and so it quietly gets the
/// base value. No exception, no warning: the screen just shows something else.
///
/// Nothing else catches this. `riverpod_lint` has a rule for the case
/// (`scoped_providers_should_specify_dependencies`), and it skips every
/// provider it cannot statically prove scoped — which it can only do for
/// generated ones. DartWay writes providers by hand, so that rule stays silent
/// here no matter what.
///
/// A value that must differ per subtree travels as a family key or a
/// constructor argument. That is the whole replacement, and it puts the
/// difference in the call rather than in the widget tree somewhere above it.
class ForbiddenProviderScopeRule extends AnalysisRule {
  ForbiddenProviderScopeRule()
    : super(
        name: 'forbidden_provider_scope',
        description:
            'The app never writes a ProviderScope; DwAppRunner and tests do.',
      );

  static const LintCode code = LintCode(
    'forbidden_provider_scope',
    'ProviderScope is created by DwAppRunner, not by the app: an override in '
        'a nested scope is invisible to providers reading through Ref.',
    correctionMessage:
        'Pass the value as a family key or a constructor argument. Tests may '
        'build their own scope.',
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
    if (dwIsTestFile(path) || dwIsGeneratedFile(path)) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  // Matched by name rather than by type: the rule has to hold in the package
  // that has not yet added riverpod as much as in the one that has, and an
  // unresolved type would make it silently pass.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'ProviderScope') {
      rule.reportAtNode(node.constructorName);
    }
  }
}
