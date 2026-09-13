import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// How names are spelled inside one library.
///
/// A generated part has no imports of its own: every name it writes must
/// resolve in the scope of the library that owns it, including through an
/// import prefix. Types are therefore spelled by looking the element up in that
/// scope rather than by printing the type, which would drop prefixes and name
/// types the library cannot see.
final class LibraryNames {
  LibraryNames(this.library);

  final LibraryElement library;

  LibraryFragment get _fragment => library.firstFragment;

  /// The spelling of [element] in this library (`Name` or `prefix.Name`), or
  /// `null` when the library cannot see it.
  String? nameOf(Element element) {
    final name = element.name;
    if (name == null) return null;
    if (_fragment.scope.lookup(name).getter == element) return name;
    for (final prefix in _fragment.prefixes) {
      if (prefix.scope.lookup(name).getter == element) {
        return '${prefix.name}.$name';
      }
    }
    return null;
  }

  /// The spelling of [type], or `null` when a name in it is not visible.
  String? spell(DartType type) {
    final suffix = type.nullabilitySuffix == NullabilitySuffix.question
        ? '?'
        : '';
    switch (type) {
      case InterfaceType():
        final name = nameOf(type.element);
        if (name == null) return null;
        if (type.typeArguments.isEmpty) return '$name$suffix';
        final arguments = <String>[];
        for (final argument in type.typeArguments) {
          final spelled = spell(argument);
          if (spelled == null) return null;
          arguments.add(spelled);
        }
        return '$name<${arguments.join(', ')}>$suffix';
      case VoidType():
        return 'void';
      case DynamicType():
        return 'dynamic';
      default:
        return type.getDisplayString();
    }
  }

  /// The spelling of the decoder of [dto]: its static `fromJson` when it
  /// declares one (the framework's hand-written DTOs), otherwise the generated
  /// `$NameFromJson` — or `null` when that function will not be visible here.
  String? decoderOf(InterfaceElement dto) {
    final spelledClass = nameOf(dto);
    if (spelledClass == null) return null;
    final staticFromJson = dto.getMethod('fromJson');
    if (staticFromJson != null && staticFromJson.isStatic) {
      return '$spelledClass.fromJson';
    }
    final function = '\$${dto.name}FromJson';
    if (dto.library == library) return function;

    final dot = spelledClass.indexOf('.');
    final prefixName = dot < 0 ? null : spelledClass.substring(0, dot);
    final spelledFunction = prefixName == null
        ? function
        : '$prefixName.$function';

    // Already generated: the scope answers directly.
    final imports = <LibraryImport>[];
    if (prefixName == null) {
      if (_fragment.scope.lookup(function).getter is TopLevelFunctionElement) {
        return function;
      }
      imports.addAll(_fragment.libraryImports.where((i) => i.prefix == null));
    } else {
      final prefix = _fragment.prefixes.firstWhere((p) => p.name == prefixName);
      if (prefix.scope.lookup(function).getter is TopLevelFunctionElement) {
        return spelledFunction;
      }
      imports.addAll(prefix.imports);
    }

    // Not generated yet: it will be exported exactly like the class, unless
    // the import that brings the class in filters it out by name.
    for (final import in imports) {
      if (import.importedLibrary?.exportNamespace.get2(dto.name!) != dto) {
        continue;
      }
      if (_passes(import, dto.name!) && _passes(import, function)) {
        return spelledFunction;
      }
    }
    return null;
  }

  static bool _passes(LibraryImport import, String name) =>
      import.combinators.every(
        (combinator) => switch (combinator) {
          ShowElementCombinator(:final shownNames) => shownNames.contains(name),
          HideElementCombinator(:final hiddenNames) => !hiddenNames.contains(
            name,
          ),
        },
      );
}
