import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'units.dart';

/// A base in another library, with a field of a type its subclasses' library
/// does not import.
abstract class Measured extends DwDataObject {
  const Measured({required this.unit});

  final Unit unit;
}
