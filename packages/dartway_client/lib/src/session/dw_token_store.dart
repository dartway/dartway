import 'package:dartway_core_shared/dartway_core_shared.dart';

/// Where a client keeps its session between runs.
///
/// It stores the whole [DwAuthSession], not only the token: the account id is
/// what state is keyed by and what an app renders before the server has seen
/// the token, and it came from the server in the first place.
abstract interface class DwTokenStore {
  /// The stored session, or `null` when signed out.
  Future<DwAuthSession?> read();

  Future<void> write(DwAuthSession session);

  Future<void> clear();
}

/// A store that forgets on exit: tests, and apps that do not keep sessions.
final class DwMemoryTokenStore implements DwTokenStore {
  DwMemoryTokenStore([this._session]);

  DwAuthSession? _session;

  /// The session as currently stored — for assertions.
  DwAuthSession? get session => _session;

  @override
  Future<DwAuthSession?> read() async => _session;

  @override
  Future<void> write(DwAuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
