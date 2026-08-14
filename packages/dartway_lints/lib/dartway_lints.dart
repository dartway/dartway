import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _DartwayLintsPlugin();

class _DartwayLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    ForbiddenUiStyleUsageRule(),
    DeepRelativeImportRule(),
    ForbiddenProviderScopeRule(),
    ModelRebuildByConstructorRule(),
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

/// Where `serverpod generate` writes its models: `lib/src/protocol/` in a
/// client package, `lib/src/generated/` in a server one. Not covered by
/// [_isGeneratedFile] — serverpod names its output after the model, not after
/// the generator, so there is no suffix to recognise.
///
/// Recognised by the two-segment tail rather than by `protocol` alone: a
/// hand-written `lib/protocol/` of one's own is somebody's code, and the point
/// of this check is that nobody wrote what it skips.
bool _isServerpodGeneratedFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/lib/src/protocol/') ||
      normalized.contains('/lib/src/generated/');
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
/// further away (`core/`, `shared/`, `ui_kit/`, another
/// zone) is named with a `package:` import, so the destination is visible in
/// the line rather than counted in dots.
///
/// Deliberately not `always_use_package_imports`: that one also forbids the
/// legitimate neighbour. The rule here is about **distance**, and the distance
/// doubles as a structure signal — if a "sibling" feature is suddenly four
/// levels away, it is not a sibling, and either the group fell apart or what is
/// being imported belongs in `shared/` or `common/`.
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

/// Tests are the one place a `ProviderScope` is written by hand: a widget test
/// builds its own root scope with `overrides:`, and nothing outside the tree it
/// just pumped reads through a provider's `Ref`.
bool _isTestFile(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  return segments.last.endsWith('_test.dart') ||
      segments.contains('test') ||
      segments.contains('integration_test');
}

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
class ForbiddenProviderScopeRule extends DartLintRule {
  const ForbiddenProviderScopeRule() : super(code: _code);

  static const _code = LintCode(
    name: 'forbidden_provider_scope',
    problemMessage:
        'ProviderScope is created by DwAppRunner, not by the app: an override '
        'in a nested scope is invisible to providers reading through Ref.',
    correctionMessage:
        'Pass the value as a family key or a constructor argument. Tests may '
        'build their own scope.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;

    if (_isTestFile(path) || _isGeneratedFile(path)) return;

    // Matched by name rather than by type: the rule has to hold in the package
    // that has not yet added riverpod as much as in the one that has, and an
    // unresolved type would make it silently pass.
    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name.lexeme == 'ProviderScope') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// DartWay convention: a stored Serverpod model is rebuilt with `copyWith`, and
/// the generated constructor is for creating a row that does not exist yet.
///
/// The mistake it catches is silent by construction. Serverpod makes a field
/// with `default=` (and any nullable field) an **optional** argument, so a
/// method that rebuilds a model by naming its fields —
/// `StudioIssue(id: …, title: …, …)` — keeps compiling when a field is added to
/// the model, and quietly substitutes the default for it. In a real project a
/// `priority` field was reset to `medium` on every single edit of the record it
/// belonged to; nothing in the compiler, the tests or the review could see it.
///
/// A doc comment does not close this. The method carried an honest "anything
/// added here too" note above it, and the field was added by another task that
/// never opened the file. A rule living in a comment at the far end of the
/// system is not a rule.
///
/// The signal is a non-null `id:`. A row being created never passes one — the
/// id comes back from the database — so a call that does pass one is rebuilding
/// something that already exists, and `copyWith` is what rebuilds it. Nothing
/// is lost by the ban: `copyWith` can clear a nullable field too, because the
/// generated one takes `Object? field = _Undefined` and tests
/// `field is T? ? field : this.field`, which tells "not passed" apart from
/// "passed null".
///
/// Matched through `SerializableModel` rather than through `TableRow`: on the
/// server a model implements both, but the **client** half of the same
/// generated model implements only `SerializableModel` — and the client half is
/// the one an application writes its code against, the one package where these
/// lints actually run. A `TableRow` check would be dead in exactly the place
/// the rule is for.
class ModelRebuildByConstructorRule extends DartLintRule {
  const ModelRebuildByConstructorRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_rebuild_by_constructor',
    problemMessage:
        'This rebuilds a stored model by listing its fields: a passed id means '
        'the row already exists. A field with default= or a nullable field is '
        'an optional argument, so the next one added to the model is not a '
        'compile error here — it is a silent default.',
    correctionMessage:
        'Rebuild it with copyWith. Clearing a nullable field works too: pass '
        'null, and the sentinel tells that apart from not passing it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.path;

    if (_isGeneratedFile(path) || _isServerpodGeneratedFile(path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final idArgument = _idArgument(node.argumentList);
      if (idArgument == null) return;

      // `id: null` is a row saying out loud that it does not exist yet — the
      // one shape of a field-by-field call that is not a rebuild.
      if (idArgument.expression is NullLiteral) return;

      if (!_isSerializableModel(node.staticType)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  static NamedExpression? _idArgument(ArgumentList argumentList) {
    for (final argument in argumentList.arguments) {
      if (argument is NamedExpression && argument.name.label.name == 'id') {
        return argument;
      }
    }
    return null;
  }

  /// Asks the type rather than the name: `id:` is a common argument, and only
  /// on a Serverpod model does it mean a database row.
  static bool _isSerializableModel(DartType? type) {
    if (type is! InterfaceType) return false;

    for (final supertype in type.allSupertypes) {
      final element = supertype.element;

      if (element.name == 'SerializableModel' &&
          element.library.uri.toString().startsWith('package:serverpod')) {
        return true;
      }
    }
    return false;
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
