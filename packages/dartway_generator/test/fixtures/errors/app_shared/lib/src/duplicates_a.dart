import 'package:dartway_core/dartway_core.dart';

part 'duplicates_a.dw.dart';

final class Twice extends DwActionCommand<void> with _$Twice {
  const Twice();
}

/// Collides with the framework's own DTO.
final class DwAuthSession extends DwActionCommand<void> with _$DwAuthSession {
  const DwAuthSession();
}
