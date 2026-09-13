import 'package:dartway_core/dartway_core.dart';

import 'units.dart';

/// A base in another library, with a field of a type its subclasses' library
/// does not import.
abstract class Measured extends DwDataObject {
  const Measured({required this.unit});

  final Unit unit;
}
