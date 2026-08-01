import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _DartwayLintsPlugin();

class _DartwayLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    ForbiddenUiStyleUsageRule(),
    DeepRelativeImportRule(),
  ];
}

bool _isUiKitFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').contains('ui_kit');
}

/// Generated code is not written by anyone, so there is no one to tell.
bool _isGeneratedFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('.g.dart') ||
      normalized.endsWith('.freezed.dart') ||
      normalized.endsWith('.gen.dart');
}

/// The theme getters the app's `ui_kit/` defines on `BuildContext`. Reaching
/// for them in feature code is how a style escapes the kit.
const _forbiddenContextGetters = {'theme', 'textTheme', 'colorScheme'};

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
/// further away (`core/`, `data/`, `domain/`, `shared/`, `ui_kit/`, another
/// zone) is named with a `package:` import, so the destination is visible in
/// the line rather than counted in dots.
///
/// Deliberately not `always_use_package_imports`: that one also forbids the
/// legitimate neighbour. The rule here is about **distance**, and the distance
/// doubles as a structure signal — if a "sibling" feature is suddenly four
/// levels away, it is not a sibling, and either the group fell apart or what is
/// being imported belongs in `shared/` or `domain/`.
class DeepRelativeImportRule extends DartLintRule {
  const DeepRelativeImportRule() : super(code: _code);

  static const _code = LintCode(
    name: 'deep_relative_import',
    problemMessage:
        'A relative import may reach at most $_maxRelativeImportDepth levels '
        'up — beyond that the path names nothing. Import it as package:… '
        'instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (_isGeneratedFile(resolver.path)) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      if (_upwardSteps(uri) <= _maxRelativeImportDepth) return;

      reporter.atNode(node.uri, code);
    });
  }

  /// How many leading `../` the import walks up. `package:` and `dart:` URIs
  /// have none by construction, so they never reach the check.
  static int _upwardSteps(String uri) {
    var steps = 0;
    for (final segment in uri.split('/')) {
      if (segment != '..') break;
      steps++;
    }
    return steps;
  }
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
        'UI styles (Color, TextStyle, BorderRadius, Theme access) must not be '
        'used outside ui_kit.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;

    if (_isUiKitFile(path) || _isGeneratedFile(path)) return;

    // Color(...), TextStyle(...), BorderRadius(...)
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Color' ||
          typeName == 'TextStyle' ||
          typeName == 'BorderRadius') {
        reporter.atNode(node, code);
      }
    });

    // `Colors.red`, `BorderRadius.circular(8)` — and `context.textTheme`.
    //
    // The last one used to be handled as a PropertyAccess, which it never is:
    // when the target is a simple identifier the analyzer builds a
    // PrefixedIdentifier instead, so that branch was dead code and the rule
    // silently allowed the very thing its message promised to catch.
    context.registry.addPrefixedIdentifier((node) {
      final prefix = node.prefix;

      if (prefix.name == 'Colors' || prefix.name == 'BorderRadius') {
        reporter.atNode(node, code);
        return;
      }

      if (_isBuildContext(prefix) &&
          _forbiddenContextGetters.contains(node.identifier.name)) {
        reporter.atNode(node, code);
      }
    });

    // `this.context.textTheme`, `widget.context.theme` — a target that is not a
    // plain identifier really does arrive as a PropertyAccess.
    context.registry.addPropertyAccess((node) {
      final target = node.target;

      if (target != null &&
          _isBuildContext(target) &&
          _forbiddenContextGetters.contains(node.propertyName.name)) {
        reporter.atNode(node, code);
      }
    });

    // `Theme.of(context)` — the message promises to catch theme access, and
    // this is the plainest form of it.
    context.registry.addMethodInvocation((node) {
      final target = node.target;

      if (node.methodName.name == 'of' &&
          target is SimpleIdentifier &&
          target.name == 'Theme') {
        reporter.atNode(node, code);
      }
    });
  }

  /// Asks the type system rather than the spelling: a variable named `ctx` is
  /// just as much a `BuildContext` as one named `context`.
  static bool _isBuildContext(Expression expression) {
    final type = expression.staticType;
    if (type == null) return false;

    final name = type.getDisplayString();
    return name == 'BuildContext';
  }
}
