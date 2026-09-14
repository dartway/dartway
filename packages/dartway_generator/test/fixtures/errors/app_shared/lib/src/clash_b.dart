import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'clash_b.dw.dart';

/// Not a DTO, but the registry imports this library and names `Tag`.
class Tag {}

final class Label extends DwActionCommand<void> with _$Label {
  const Label();
}
