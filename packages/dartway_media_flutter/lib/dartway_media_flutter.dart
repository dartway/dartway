/// A video/audio player for a DartWay app — `dw.plugins.media`.
///
/// Mechanism only: one controller API over `video_player` and `just_audio`,
/// a session that survives route changes, a queue, resume, fullscreen and a
/// mini-player. No look — see `docs/3-flutter/media.md` and the
/// `dartway-media` toolkit skill for the default controls, which live as
/// source in `example/`, not in this package.
library;

export 'src/config/dw_media_config.dart';
export 'src/dw_media.dart';
export 'src/miniplayer/dw_mini_player_host.dart';
export 'src/model/dw_media_callbacks.dart';
export 'src/model/dw_media_item.dart';
export 'src/model/dw_media_playback_state.dart';
export 'src/resume/dw_media_position_store.dart';
export 'src/session/dw_media_queue_state.dart';
export 'src/session/dw_media_session_manager.dart';
export 'src/widgets/dw_video_surface.dart';
