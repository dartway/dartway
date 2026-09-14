import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'declaration.dw.dart';

final class NoMixin extends DwActionCommand<void> {
  const NoMixin();

  @override
  String get dwTypeName => 'NoMixin';

  @override
  Map<String, Object?> toJson() => const {};
}

final class Generic<T> extends DwActionCommand<T> with _$Generic<T> {
  const Generic();
}

final class Bare extends DwWireObject with _$Bare {
  const Bare();
}

final class Implements extends Object
    with _$Implements
    implements DwActionCommand<void> {
  const Implements();
}

final class _Private extends DwActionCommand<void> with _$_Private {
  const _Private();
}
