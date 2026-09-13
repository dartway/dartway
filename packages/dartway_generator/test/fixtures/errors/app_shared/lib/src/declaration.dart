import 'package:dartway_core/dartway_core.dart';

part 'declaration.dw.dart';

final class NoMixin extends DwCommand<void> {
  const NoMixin();

  @override
  String get dwTypeName => 'NoMixin';

  @override
  Map<String, Object?> toJson() => const {};
}

final class Generic<T> extends DwCommand<T> with _$Generic<T> {
  const Generic();
}

final class Bare extends DwDto with _$Bare {
  const Bare();
}

final class Implements extends Object with _$Implements implements DwCommand<void> {
  const Implements();
}

final class _Private extends DwCommand<void> with _$_Private {
  const _Private();
}
