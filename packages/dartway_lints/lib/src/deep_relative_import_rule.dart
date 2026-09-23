import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'paths.dart';

/// How far a relative import may reach before it stops describing anything.
///
/// One or two `../` read as "the feature next door"; three or four mean the
/// import left its group, and by then the path says nothing about where it
/// lands — `'../../../../ui_kit/ui_kit.dart'` tells the reader neither what is
/// imported nor from where, while `package:my_app_flutter/ui_kit/ui_kit.dart`
/// tells both.
const _maxRelativeImportDepth = 2;

/// DartWay convention: a relative import is for **neighbours** — the feature's
/// own `widgets/`/`logic/` and a sibling feature in the same group. Anything
/// further away (`core/`, `shared/`, `ui_kit/`, another zone) is named with a
/// `package:` import, so the destination is visible in the line rather than
/// counted in dots.
///
/// Deliberately not `always_use_package_imports`: that one also forbids the
/// legitimate neighbour. The rule here is about **distance**, and the distance
/// doubles as a structure signal — if a "sibling" feature is suddenly four
/// levels away, it is not a sibling, and either the group fell apart or what is
/// being imported belongs in `shared/` or `common/`.
class DeepRelativeImportRule extends AnalysisRule {
  DeepRelativeImportRule()
    : super(
        name: 'deep_relative_import',
        description:
            'A relative import reaches at most two levels up; beyond that it '
            'is a package: import.',
      );

  static const LintCode code = LintCode(
    'deep_relative_import',
    'A relative import may reach at most $_maxRelativeImportDepth levels up — '
        'beyond that the path names nothing. Import it as package:… instead.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (dwIsGeneratedFile(dwPathOf(context))) return;
    registry.addImportDirective(this, _Visitor(this));
  }

  /// How many leading `../` the import walks up. `package:` and `dart:` URIs
  /// have none by construction, so they never reach the check.
  static int upwardSteps(String uri) {
    var steps = 0;
    for (final segment in uri.split('/')) {
      if (segment != '..') break;
      steps++;
    }
    return steps;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) return;
    if (DeepRelativeImportRule.upwardSteps(uri) <= _maxRelativeImportDepth) {
      return;
    }
    rule.reportAtNode(node.uri);
  }
}
