import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'empty.dw.dart';

/// Declares the part but nothing to generate (the last DTO was just removed):
/// the part stays, empty, so the library keeps compiling.
abstract class Base extends DwDataObject {
  const Base();
}
