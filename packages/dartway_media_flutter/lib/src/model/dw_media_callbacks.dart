import 'dw_media_item.dart';

/// What a session reports while it plays — given once, to `DwMedia.open()`,
/// and covering every item of the queue. When each one fires is tuned in
/// `DwMediaConfig` (`progressInterval`, `completedThreshold`,
/// `reachedEndTolerance`), not here.
final class DwMediaCallbacks {
  const DwMediaCallbacks({
    this.onStarted,
    this.onProgress,
    this.onReachedEnd,
    this.onCompleted,
    this.onError,
    this.onItemChanged,
  });

  /// Once per item, when it really plays: the engine says it plays **and**
  /// the position has moved. A web `play()` the browser refused, which
  /// `video_player` reports as playing all the same, does not count.
  final void Function(DwMediaItem item)? onStarted;

  /// While the item really plays, at most every
  /// `DwMediaConfig.progressInterval`.
  final void Function(DwMediaItem item, Duration position, Duration duration)?
  onProgress;

  /// Once per item, when real playback reaches the end. A seek to the end —
  /// a scrub, a resume point — never counts, although both engines report it
  /// as completed (see `DwMediaEngineController`).
  final void Function(DwMediaItem item)? onReachedEnd;

  /// Once per item, when the position first crosses
  /// `DwMediaConfig.completedThreshold` — by playback or by a seek.
  final void Function(DwMediaItem item)? onCompleted;

  /// Each time the controller enters `DwMediaPlayState.error`.
  final void Function(DwMediaItem item, Object error)? onError;

  /// When the queue moves to another item.
  final void Function(DwMediaItem item)? onItemChanged;
}
