import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import 'dw_audio_media_controller.dart';
import 'dw_media_controller.dart';
import 'dw_video_media_controller.dart';

/// The engine for `item.kind` — what a session builds for its current item.
/// Not exported: a controller outside a session escapes `singleActiveItem`
/// and the background rules.
DwMediaController createDwMediaController({
  required DwMediaItem item,
  required DwMediaCallbacks callbacks,
  required DwMediaConfig options,
  double? initialSpeed,
  bool? initialMuted,
  void Function()? onPlaybackEnd,
}) => switch (item.kind) {
  DwMediaKind.video => DwVideoMediaController(
    item: item,
    callbacks: callbacks,
    options: options,
    initialSpeed: initialSpeed,
    initialMuted: initialMuted,
    onPlaybackEnd: onPlaybackEnd,
  ),
  DwMediaKind.audio => DwAudioMediaController(
    item: item,
    callbacks: callbacks,
    options: options,
    initialSpeed: initialSpeed,
    initialMuted: initialMuted,
    onPlaybackEnd: onPlaybackEnd,
  ),
};
