import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'units.dw.dart';

enum Unit { kg, pcs }

/// Imported by `catalog.dart` under a prefix.
final class Dimensions extends DwDataObject with _$Dimensions {
  const Dimensions({required this.id, required this.width, this.height});

  @override
  final String id;
  final double width;
  final double? height;
}
