import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/fields.dart';
import '../analysis/framework.dart';
import '../analysis/library_names.dart';
import '../analysis/wire_type.dart';
import '../diagnostic.dart';
import 'dto_model.dart';

/// Reads one concrete DTO class into a [DtoClass], reporting everything that
/// stops it from being generated.
final class DtoReader {
  DtoReader(this.names, this.diagnostics) : types = WireTypeReader(names);

  final LibraryNames names;
  final WireTypeReader types;
  final List<DwDiagnostic> diagnostics;

  DtoClass? read(
    ClassElement element,
    DtoKind kind,
    ClassDeclaration declaration,
  ) {
    final name = element.name!;
    if (kind == DtoKind.bare) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          '`$name` extends DwDto directly; extend DwDataObject, a DwRequest '
          'kind or DwCommand',
        ),
      );
      return null;
    }
    final extendsClause = declaration.extendsClause;
    if (extendsClause == null || !_reachesKindBySuperclass(element)) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          '`$name` must extend its DTO kind (`extends DwDataObject`, a '
          'DwRequest kind or DwCommand); implementing or mixing it in is not '
          'supported',
        ),
      );
      return null;
    }
    if (element.typeParameters.isNotEmpty) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          '`$name` is generic; a DTO class cannot have type parameters, '
          'because its decoder cannot know them',
        ),
      );
      return null;
    }

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
          DwDiagnostic.at(
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
          DwDiagnostic.at(
            location,
            'field `${field.name}` of `$name` has a type this library does not '
            'import, and the generated part can only use the library\'s imports',
          ),
        );
        valid = false;
        continue;
      }
      fields.add(
        DtoField(
          name: field.name,
          type: type,
          spelling: spelling,
          omitWhenEmpty:
              !type.nullable &&
              (type is ListWire || type is MapWire) &&
              _defaultsToEmpty(field.parameter),
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
      current != null && !DwFramework.isFramework(current);
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
        DwDiagnostic.at(
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
        DwDiagnostic.at(
          location,
          'the id of data object `$name` must be `int` or `String`, not '
          '`${idType.getDisplayString()}`',
        ),
      );
    }
    return isValid;
  }

  static bool _reachesKindBySuperclass(ClassElement element) {
    for (
      var type = element.supertype;
      type != null;
      type = type.element.supertype
    ) {
      final superElement = type.element;
      if (DwFramework.isCoreClass(superElement, 'DwDataObject') ||
          DwFramework.isCoreClass(superElement, 'DwRequest') ||
          DwFramework.isCoreClass(superElement, 'DwCommand')) {
        return true;
      }
    }
    return false;
  }

  /// Whether the constructor default of [parameter] is an empty collection —
  /// the only case in which an empty value can be left off the wire and still
  /// decode to an equal object.
  static bool _defaultsToEmpty(FormalParameterElement parameter) {
    if (!parameter.hasDefaultValue) return false;
    final value = parameter.computeConstantValue();
    if (value == null) return false;
    final list = value.toListValue();
    if (list != null) return list.isEmpty;
    final map = value.toMapValue();
    return map != null && map.isEmpty;
  }
}
