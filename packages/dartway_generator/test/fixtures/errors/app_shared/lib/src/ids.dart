import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'ids.dw.dart';

final class DoubleId extends DwDataObject with _$DoubleId {
  const DoubleId({required this.id});

  @override
  final double id;
}

final class NullableId extends DwDataObject with _$NullableId {
  const NullableId({this.id});

  @override
  final int? id;
}

final class NoId extends DwDataObject with _$NoId {
  const NoId({required this.name});

  final String name;
}
