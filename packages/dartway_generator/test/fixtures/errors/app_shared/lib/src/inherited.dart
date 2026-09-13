import 'package:dartway_core/dartway_core.dart';

import 'base.dart';

part 'inherited.dw.dart';

final class Parcel extends Measured with _$Parcel {
  const Parcel({required this.id, required super.unit});

  @override
  final int id;
}
