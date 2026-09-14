import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Recognises the framework's own types by library, not by name alone, so a
/// project class that happens to be called `DwActionCommand` is never mistaken
/// for the real one.
abstract final class DwFrameworkTypes {
  static const corePackage = 'dartway_core';
  static const ormPackage = 'dartway_orm';

  static bool isFrom(Element element, String package) =>
      element.library?.uri.toString().startsWith('package:$package/') ?? false;

  /// Whether [element] belongs to a framework package: those classes are the
  /// ends of a DTO or row class hierarchy and are never generated for.
  static bool isFramework(Element element) =>
      isFrom(element, corePackage) || isFrom(element, ormPackage);

  static bool isCoreClass(Element element, String name) =>
      element is InterfaceElement &&
      element.name == name &&
      isFrom(element, corePackage);

  static bool isOrmClass(Element element, String name) =>
      element is InterfaceElement &&
      element.name == name &&
      isFrom(element, ormPackage);

  /// The DTO kind [element] is, or `null` when it is not a DTO.
  static DtoKind? dtoKindOf(InterfaceElement element) {
    var extendsDto = false;
    for (final type in element.allSupertypes) {
      final superElement = type.element;
      if (isCoreClass(superElement, 'DwDataObject')) return DtoKind.data;
      if (isCoreClass(superElement, 'DwDataRequest')) return DtoKind.request;
      if (isCoreClass(superElement, 'DwActionCommand')) return DtoKind.command;
      if (isCoreClass(superElement, 'DwWireObject')) extendsDto = true;
    }
    return extendsDto ? DtoKind.bare : null;
  }

  /// Whether [element] is a row class (extends `DwTableRow`).
  static bool isEntity(InterfaceElement element) => element.allSupertypes.any(
    (type) => isOrmClass(type.element, 'DwTableRow'),
  );

  static bool isPatch(InterfaceType type) =>
      isCoreClass(type.element, 'DwFieldPatch');
}

/// The three kinds of DTO a project declares, plus [bare] for a class that
/// extends `DwWireObject` directly — which a project must not do, and is
/// reported.
enum DtoKind { data, request, command, bare }
