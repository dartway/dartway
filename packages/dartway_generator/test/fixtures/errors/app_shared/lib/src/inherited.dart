import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'base.dart';

part 'inherited.dw.dart';

final class Parcel extends Measured with _$Parcel {
  const Parcel({required this.id, required super.unit});

  @override
  final int id;
}
