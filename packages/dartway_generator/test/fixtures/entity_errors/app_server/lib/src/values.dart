import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'values.dw.dart';

final class ValueView extends DwDataObject with _$ValueView {
  const ValueView({required this.id});

  @override
  final int id;
}
