import 'package:dartway_core/dartway_core.dart';

part 'clash_b.dw.dart';

/// Not a DTO, but the registry imports this library and names `Tag`.
class Tag {}

final class Label extends DwCommand<void> with _$Label {
  const Label();
}
