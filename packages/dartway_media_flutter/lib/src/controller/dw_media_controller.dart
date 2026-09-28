import 'package:flutter/foundation.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';
import 'dw_audio_media_controller.dart';
import 'dw_video_media_controller.dart';

/// One controller API over both engines — a controls widget is written once
/// against this type and works for a video item and an audio item alike.
///
/// A controller is bound to exactly one [DwMediaItem] for its whole life:
/// `DwMediaSession` creates a fresh one for whichever item is current and
/// disposes it when the queue moves on, rather than re-pointing one instance
/// at a new source.
abstract class DwMediaController {
  const DwMediaController();

  /// Builds the right engine for `item.kind` — used by `DwMediaSession`, not
  /// normally called directly by app code. [options] is the session's already
  /// resolved [DwMediaConfig] (`DwMediaConfig.merge`), never the sparse
  /// per-open override.
  factory DwMediaController.forItem({
    required DwMediaItem item,
    required DwMediaCallbacks callbacks,
    required DwMediaConfig options,
    double? initialSpeed,
  }) {
    return switch (item.kind) {
      DwMediaKind.video => DwVideoMediaController(
        item: item,
        callbacks: callbacks,
        options: options,
        initialSpeed: initialSpeed,
      ),
      DwMediaKind.audio => DwAudioMediaController(
        item: item,
        callbacks: callbacks,
        options: options,
        initialSpeed: initialSpeed,
      ),
    };
  }

  DwMediaItem get item;

  ValueListenable<DwMediaPlaybackState> get state;

  Future<void> play();

  /// Pauses and, when a resume policy is set with
  /// `DwMediaResumePolicy.saveOnLifecycleEvents`, saves the position.
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

  /// Re-resolves `item.source` and reloads — the way an expired signed link
  /// recovers. Callable from [DwMediaPlayState.error] and at any other time;
  /// also what `options.autoRetryCount` calls on a load failure.
  Future<void> retry();

  Future<void> dispose();
}
