import 'package:dartway_core/dartway_core.dart';

part 'values.dw.dart';

final class ValueView extends DwDataObject with _$ValueView {
  const ValueView({required this.id});

  @override
  final int id;
}
