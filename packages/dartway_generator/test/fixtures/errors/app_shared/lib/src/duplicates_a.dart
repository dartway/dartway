import 'package:dartway_core/dartway_core.dart';

part 'duplicates_a.dw.dart';

final class Twice extends DwCommand<void> with _$Twice {
  const Twice();
}

/// Collides with the framework's own DTO.
final class DwSession extends DwCommand<void> with _$DwSession {
  const DwSession();
}
