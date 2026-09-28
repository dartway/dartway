import 'dw_media_item.dart';

/// What a session reports while it plays — supplied once, to
/// `DwMedia.open()`/`DwMediaSession`, so it covers every item the queue plays
/// without being re-declared per item.
final class DwMediaCallbacks {
  const DwMediaCallbacks({
    this.onStarted,
    this.onProgress,
    this.progressInterval = const Duration(seconds: 1),
    this.onReachedEnd,
    this.onCompleted,
    this.completedThreshold = 0.9,
    this.onError,
    this.onItemChanged,
  }) : assert(
         completedThreshold > 0 && completedThreshold <= 1,
         'completedThreshold must be in (0, 1]',
       );

  /// Fired once per item, the first time it actually starts playing —
  /// after loading, and again for each item the queue advances to.
  final void Function(DwMediaItem item)? onStarted;

  /// Fired at most every [progressInterval] while playing.
  final void Function(DwMediaItem item, Duration position, Duration duration)?
  onProgress;
  final Duration progressInterval;

  /// Fired once when the engine reports **real playback** reaching the end —
  /// never when the position merely equals the duration, which a scrub to the
  /// end satisfies too on both engines (see the two controllers' docs for the
  /// platform quirks this is guarded against).
  final void Function(DwMediaItem item)? onReachedEnd;

  /// Fired once, the first time the position crosses [completedThreshold] of
  /// the duration.
  final void Function(DwMediaItem item)? onCompleted;
  final double completedThreshold;

  final void Function(DwMediaItem item, Object error)? onError;

  /// Fired when the session's current item changes — advancing the queue,
  /// not a property of the item itself.
  final void Function(DwMediaItem item)? onItemChanged;
}
