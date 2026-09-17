import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/fields.dart';
import '../analysis/framework.dart';
import '../analysis/library_names.dart';
import '../analysis/wire_type.dart';
import '../diagnostic.dart';
import 'default_value_writer.dart';
import 'dto_model.dart';

/// Reads one concrete DTO class into a [DtoClass], reporting everything that
/// stops it from being generated.
final class DtoReader {
  DtoReader(this.names, this.diagnostics)
    : types = WireTypeReader(names),
      defaults = DefaultValueWriter(names);

  final LibraryNames names;
  final WireTypeReader types;
  final DefaultValueWriter defaults;
  final List<DwGenerationDiagnostic> diagnostics;

  DtoClass? read(
    ClassElement element,
    DtoKind kind,
    ClassDeclaration declaration,
  ) {
    final name = element.name!;
    if (kind == DtoKind.bare) {
      diagnostics.add(
        DwGenerationDiagnostic.at(
          element,
          '`$name` extends DwWireObject directly; extend DwDataObject, a DwDataRequest '
          'kind or DwActionCommand',
        ),
      );
      return null;
    }
    final extendsClause = declaration.extendsClause;
    if (extendsClause == null || !_reachesKindBySuperclass(element)) {
      diagnostics.add(
        DwGenerationDiagnostic.at(
          element,
          '`$name` must extend its DTO kind (`extends DwDataObject`, a '
          'DwDataRequest kind or DwActionCommand); implementing or mixing it in is not '
          'supported',
        ),
      );
      return null;
    }
    if (element.typeParameters.isNotEmpty) {
      diagnostics.add(
        DwGenerationDiagnostic.at(
          element,
          '`$name` is generic; a DTO class cannot have type parameters, '
          'because its decoder cannot know them',
        ),
      );
      return null;
    }

    if (kind == DtoKind.command && !_hasWireResult(element)) return null;

    final constructorFields = readConstructorFields(element, diagnostics);
    if (constructorFields == null) return null;

    var valid = true;
    final fields = <DtoField>[];
    for (final field in constructorFields) {
      final location = field.field.enclosingElement == element
          ? field.field
          : element;
      final WireType type;
      try {
        type = types.read(field.type);
      } on UnsupportedType catch (problem) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            location,
            'field `${field.name}` of `$name` cannot be serialised: '
            '${problem.reason}',
          ),
        );
        valid = false;
        continue;
      }
      final spelling = names.spell(field.type);
      if (spelling == null) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            location,
            'field `${field.name}` of `$name` has a type this library does not '
            'import, and the generated part can only use the library\'s imports',
          ),
        );
        valid = false;
        continue;
      }
      DtoDefault? defaultValue;
      final parameter = field.parameter;
      if (type is! PatchWire && parameter.hasDefaultValue) {
        final value = parameter.computeConstantValue();
        try {
          defaultValue = value == null
              ? throw const UnsupportedDefault('it does not evaluate')
              : defaults.write(value);
        } on UnsupportedDefault catch (problem) {
          diagnostics.add(
            DwGenerationDiagnostic.at(
              location,
              'the default of field `${field.name}` of `$name` cannot be '
              'written into the generated decoder, which applies it to an '
              'absent field: ${problem.reason}',
            ),
          );
          valid = false;
          continue;
        }
      }
      fields.add(
        DtoField(
          name: field.name,
          type: type,
          spelling: spelling,
          defaultValue: defaultValue,
        ),
      );
    }

    if (kind == DtoKind.data && !_checkId(element, constructorFields)) {
      valid = false;
    }
    if (!valid) return null;

    return DtoClass(
      name: name,
      kind: kind,
      superclass: extendsClause.superclass.toSource(),
      fields: fields,
      constConstructor: element.unnamedConstructor!.isConst,
    );
  }

  /// A data object's identity must be an `int` or a `String`: updates are
  /// merged by it and it travels as a JSON key value. A getter is fine too —
  /// a singleton view has a fixed id that is not a field.
  bool _checkId(ClassElement element, List<ConstructorField> fields) {
    final name = element.name!;
    DartType? idType;
    Element? idElement;
    for (
      InterfaceElement? current = element;
      current != null && !DwFrameworkTypes.isFramework(current);
      current = current.supertype?.element
    ) {
      final field = current.getField('id');
      if (field != null && field.isOriginDeclaration) {
        idType = field.type;
        idElement = field;
        break;
      }
      final getter = current.getGetter('id');
      if (getter != null) {
        idType = getter.returnType;
        idElement = getter;
        break;
      }
    }
    if (idType == null) {
      diagnostics.add(
        DwGenerationDiagnostic.at(
          element,
          'data object `$name` declares no `id`; add `@override final int id;` '
          '(or a String) or an `id` getter',
        ),
      );
      return false;
    }
    final isValid =
        (idType.isDartCoreInt || idType.isDartCoreString) &&
        idType.nullabilitySuffix == NullabilitySuffix.none;
    if (!isValid) {
      final location = idElement!.enclosingElement == element
          ? idElement
          : element;
      diagnostics.add(
        DwGenerationDiagnostic.at(
          location,
          'the id of data object `$name` must be `int` or `String`, not '
          '`${idType.getDisplayString()}`',
        ),
      );
    }
    return isValid;
  }

  /// Whether the command's result type is one the wire carries — `void`, a
  /// JSON primitive or a DTO, each possibly nullable (see `DwActionCommand`).
  /// Anything else compiles and fails only when the first result is encoded.
  bool _hasWireResult(ClassElement element) {
    final command = element.allSupertypes.firstWhere(
      (type) => DwFrameworkTypes.isCoreClass(type.element, 'DwActionCommand'),
    );
    final result = command.typeArguments.single;
    if (result is VoidType || result.isDartCoreNull) return true;
    if (result is InterfaceType) {
      if (result.isDartCoreInt ||
          result.isDartCoreDouble ||
          result.isDartCoreNum ||
          result.isDartCoreString ||
          result.isDartCoreBool) {
        return true;
      }
      final isDto = [
        result.element,
        ...result.element.allSupertypes.map((type) => type.element),
      ].any((type) => DwFrameworkTypes.isCoreClass(type, 'DwWireObject'));
      if (isDto && result.element.typeParameters.isEmpty) return true;
    }
    diagnostics.add(
      DwGenerationDiagnostic.at(
        element,
        'the result of command `${element.name}` is '
        '`${result.getDisplayString()}`; a command answers void, a JSON '
        'primitive (int, double, num, String, bool) or a DTO, each possibly '
        'nullable — wrap a collection in a DTO',
      ),
    );
    return false;
  }

  static bool _reachesKindBySuperclass(ClassElement element) {
    for (
      var type = element.supertype;
      type != null;
      type = type.element.supertype
    ) {
      final superElement = type.element;
      if (DwFrameworkTypes.isCoreClass(superElement, 'DwDataObject') ||
          DwFrameworkTypes.isCoreClass(superElement, 'DwDataRequest') ||
          DwFrameworkTypes.isCoreClass(superElement, 'DwActionCommand')) {
        return true;
      }
    }
    return false;
  }
}
