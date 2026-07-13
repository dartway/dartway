import 'package:analyzer/dart/ast/ast.dart';
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
