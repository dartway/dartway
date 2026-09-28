/// Where a [DwMediaController] keeps "how far into this item was I".
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

/// When a controller saves the position it plays, and when it gives up on the
/// item entirely.
///
/// - Saved every [saveInterval], and on pause, on the app going to the
///   background, and on dispose.
/// - A position under [minimum] is never saved — nothing is lost by restarting
///   the first few seconds, and it keeps a title that was only glanced at from
///   claiming a resume point.
/// - Once playback passes [clearPastFraction] of the duration the saved
///   position is cleared instead of updated — the item is done, and a stray
///   9-minutes-into-a-10-minute-video resume point would be worse than none.
final class DwMediaResumePolicy {
  const DwMediaResumePolicy({
    this.saveInterval = const Duration(seconds: 5),
    this.minimum = const Duration(seconds: 5),
    this.clearPastFraction = 0.9,
  }) : assert(
         clearPastFraction > 0 && clearPastFraction <= 1,
         'clearPastFraction must be in (0, 1]',
       );

  final Duration saveInterval;
  final Duration minimum;
  final double clearPastFraction;
}
