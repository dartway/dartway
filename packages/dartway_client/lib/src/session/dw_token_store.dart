import 'package:dartway_core/dartway_core.dart';

/// Where a client keeps its session between runs.
///
/// It stores the whole [DwSession], not only the token: the account id is what
/// an app renders while offline or before the server has confirmed the token,
/// and it came from the server in the first place.
abstract interface class DwTokenStore {
  /// The stored session, or `null` when signed out.
  Future<DwSession?> read();

  Future<void> write(DwSession session);

  Future<void> clear();
}

/// A store that forgets on exit: tests, and apps that do not keep sessions.
final class DwMemoryTokenStore implements DwTokenStore {
  DwMemoryTokenStore([this._session]);

  DwSession? _session;

  /// The session as currently stored — for assertions.
  DwSession? get session => _session;

  @override
  Future<DwSession?> read() async => _session;

  @override
  Future<void> write(DwSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
