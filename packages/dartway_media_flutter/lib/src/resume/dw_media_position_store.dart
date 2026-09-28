/// Where a session keeps "how far into this item was I".
///
/// The default, [DwMediaInMemoryPositionStore], forgets on restart — a
/// project that wants resume across launches gives `DwMediaConfig` a store
/// backed by `dw.plugins.prefs` or its own storage. **The app decides "resume
/// or start over"**: this interface only remembers a position: reading it at
/// open time and asking the person is the app's UI, not the package's.
abstract interface class DwMediaPositionStore {
  Future<Duration?> read(String itemId);
  Future<void> write(String itemId, Duration position);
  Future<void> clear(String itemId);
}

/// The default [DwMediaPositionStore] — positions last for the process only.
final class DwMediaInMemoryPositionStore implements DwMediaPositionStore {
  final Map<String, Duration> _positions = {};

  @override
  Future<Duration?> read(String itemId) async => _positions[itemId];

  @override
  Future<void> write(String itemId, Duration position) async {
    _positions[itemId] = position;
  }

  @override
  Future<void> clear(String itemId) async {
    _positions.remove(itemId);
  }
}
