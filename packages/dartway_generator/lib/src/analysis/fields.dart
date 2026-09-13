import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../diagnostic.dart';
import 'framework.dart';

/// A field the generated code reads, writes and reconstructs.
final class ConstructorField {
  const ConstructorField(this.field, this.parameter);

  final FieldElement field;
  final FormalParameterElement parameter;

  String get name => field.name!;

  DartType get type => field.type;
}

/// Collects the serialised fields of [element]: instance fields, declared in
/// the class or in its project superclasses, that the constructor initialises
/// — the only ones a decoder can pass back in.
///
/// Returns `null` (after reporting) when the class cannot be reconstructed
/// from its fields at all.
List<ConstructorField>? readConstructorFields(
  ClassElement element,
  List<DwDiagnostic> diagnostics,
) {
  final name = element.name!;
  final constructor = element.unnamedConstructor;
  if (constructor == null || constructor.isFactory) {
    diagnostics.add(
      DwDiagnostic.at(
        element,
        '`$name` needs an unnamed generative constructor: the generated code '
        'rebuilds it as `$name(field: …)`',
      ),
    );
    return null;
  }

  // Superclass fields first: the order a reader meets them in the hierarchy.
  final chain = <ClassElement>[];
  for (
    InterfaceElement? current = element;
    current is ClassElement &&
        !DwFramework.isFramework(current) &&
        current.supertype != null;
    current = current.supertype?.element
  ) {
    chain.insert(0, current);
  }

  final parameters = {
    for (final parameter in constructor.formalParameters)
      parameter.name: parameter,
  };
  final result = <ConstructorField>[];
  var valid = true;
  final used = <String>{};
  for (final owner in chain) {
    for (final field in owner.fields) {
      if (field.isStatic ||
          !field.isOriginDeclaration ||
          field.isAbstract ||
          field.isExternal ||
          field.hasInitializer ||
          field.isLate) {
        continue;
      }
      final fieldName = field.name!;
      // Claimed even when invalid, so one mistake is reported once.
      used.add(fieldName);
      final location = owner == element ? field : element;
      if (!field.isFinal) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'field `$fieldName` of `$name` must be final: generated equality '
            'and hashing assume a value that does not change',
          ),
        );
        valid = false;
        continue;
      }
      final parameter = parameters[fieldName];
      if (parameter == null || !parameter.isNamed) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'field `$fieldName` of `$name` is serialised but the constructor '
            '${parameter == null ? 'has no' : 'has a positional, not a'} named '
            'parameter `$fieldName`; declare it as `{required this.$fieldName}` '
            '(or give the field an initializer to keep it off the wire)',
          ),
        );
        valid = false;
        continue;
      }
      if (!element.library.typeSystem.isAssignableTo(
        field.type,
        parameter.type,
      )) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'constructor parameter `$fieldName` of `$name` has type '
            '`${parameter.type.getDisplayString()}`, which does not accept the '
            'field type `${field.type.getDisplayString()}`',
          ),
        );
        valid = false;
        continue;
      }
      result.add(ConstructorField(field, parameter));
    }
  }

  for (final parameter in constructor.formalParameters) {
    if (used.contains(parameter.name)) continue;
    if (parameter.isRequiredPositional || parameter.isRequiredNamed) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          'constructor parameter `${parameter.name}` of `$name` is required '
          'but is not a serialised field, so the generated code cannot supply '
          'it',
          offset: parameter.firstFragment.nameOffset,
        ),
      );
      valid = false;
    }
  }
  return valid ? result : null;
}
