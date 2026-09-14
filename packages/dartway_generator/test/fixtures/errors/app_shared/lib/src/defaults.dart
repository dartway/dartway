import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'defaults.dw.dart';

/// A framework DTO is hand-written: its fields are not read, so a default
/// of it cannot be rebuilt for an absent field.
final class WithFrameworkDefault extends DwActionCommand<void>
    with _$WithFrameworkDefault {
  const WithFrameworkDefault({
    this.session = const DwAuthSession(id: 1, token: 't', isNewAccount: false),
  });

  final DwAuthSession session;
}
