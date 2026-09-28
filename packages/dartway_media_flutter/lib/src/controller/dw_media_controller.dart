import 'package:flutter/foundation.dart';

import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';

/// One controller API over both engines — a controls widget is written once
/// against this type and works for a video item and an audio item alike.
///
/// A controller is bound to exactly one [DwMediaItem] for its whole life:
/// `DwMediaSession` creates a fresh one for whichever item is current and
/// disposes it when the queue moves on, rather than re-pointing one instance
/// at a new source.
abstract class DwMediaController {
  const DwMediaController();

  DwMediaItem get item;

  ValueListenable<DwMediaPlaybackState> get state;

  Future<void> play();

  /// Pauses and, with `DwMediaResumePolicy.saveOnPause`, saves the position.
  Future<void> pause();

  /// Seeks to an absolute [position], clamped to `[0, duration]`.
  Future<void> seek(Duration position);

  /// Seeks by [offset] relative to the current position (negative rewinds),
  /// clamped to `[0, duration]`. `DwMediaSession.skipBack`/`skipForward` call
  /// this with `options.skipBack`/`skipForward`.
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

  Future<void> dispose();
}
