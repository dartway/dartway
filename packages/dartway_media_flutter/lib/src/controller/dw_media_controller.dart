import 'package:flutter/foundation.dart';

import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';

/// One engine for one item, over `video_player` or `just_audio` — internal to
/// the package: `DwMediaSession` creates one for its current item, disposes
/// it when the queue moves on, and is the only way an app reaches it.
abstract class DwMediaController {
  const DwMediaController();

  DwMediaItem get item;

  ValueListenable<DwMediaPlaybackState> get state;

  /// A `play()` waits for the item to load.
  bool get wantsToPlay;

  /// The item stands at its end because real playback took it there — not a
  /// seek. Cleared by the next seek.
  bool get endedByPlayback;

  Future<void> play();

  /// Pauses and, with `DwMediaResumePolicy.saveOnPause`, saves the position.
  Future<void> pause();

  /// Seeks to an absolute [position], clamped to `[0, duration]`.
  Future<void> seek(Duration position);

  /// Seeks by [offset] from the current position (negative rewinds), clamped
  /// to `[0, duration]`.
  Future<void> skip(Duration offset);

  Future<void> setSpeed(double speed);

  /// `0.0`–`1.0`. Setting a non-zero volume also unmutes.
  Future<void> setVolume(double volume);

  /// Mutes without losing the volume to restore on `setMuted(false)`.
  Future<void> setMuted(bool muted);

  /// Re-resolves `item.source`, reloads, and returns to the position the
  /// failure left — the way an expired signed link recovers. What the
  /// retry control of an error state calls, and what
  /// `DwMediaConfig.autoRetryCount` calls on its own.
  Future<void> retry();

  /// Saves the position now, under the resume policy's rules (`minimum`,
  /// `clearPastFraction`) — a no-op with resume off. `DwMedia` calls it when
  /// the app goes to the background (`DwMediaResumePolicy.saveOnBackground`).
  Future<void> savePosition();

  /// Releases the engine. The session disposes the controllers it creates;
  /// app code ends a session instead (`DwMediaSession.dispose`).
  Future<void> dispose();
}
