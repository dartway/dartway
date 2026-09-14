import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'constructor.dw.dart';

final class Positional extends DwActionCommand<void> with _$Positional {
  const Positional(this.value);

  final int value;
}

final class InitializerList extends DwActionCommand<void>
    with _$InitializerList {
  const InitializerList({required int raw}) : value = raw;

  final int value;
}

final class ExtraRequired extends DwActionCommand<void> with _$ExtraRequired {
  const ExtraRequired({required this.value, required String unused});

  final int value;
}

final class NotFinal extends DwActionCommand<void> with _$NotFinal {
  NotFinal({required this.value});

  int value;
}

final class NoUnnamedConstructor extends DwActionCommand<void>
    with _$NoUnnamedConstructor {
  const NoUnnamedConstructor.create({required this.value});

  final int value;
}
