import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';

import 'config/dw_media_config.dart';
import 'model/dw_media_callbacks.dart';
import 'model/dw_media_item.dart';
import 'session/dw_media_session_manager.dart';

/// Video and audio for a DartWay app — `dw.plugins.media`.
///
/// Mechanism only: no colours, no icons, no text, no built-in controls. The
/// controls a project shows are its own widgets, copied from `example/`'s
/// `ui_kit/3_special/media/` (the `dartway-media` toolkit skill walks
/// through it).
///
/// ```dart
/// DwFlutterToolbox(plugins: [DwMedia(config: DwMediaConfig(speeds: [1, 1.5, 2]))]);
///
/// final session = dw.plugins.media.open(
///   items: [DwMediaItem(id: 'intro', kind: DwMediaKind.video, source: DwMediaSource.url(url))],
/// );
/// ```
///
/// **The plugin owns the sessions**, not the widgets that opened them, which
/// is what lets playback survive navigation, the mini-player and fullscreen.
/// It also applies the background rules to every open session: on the app
/// going to the background (`hidden`, `paused`, `detached` — never
/// `inactive`, which a system dialog or a permission prompt raises too) it
/// saves positions under `DwMediaResumePolicy.saveOnBackground` and pauses
/// under `pauseVideoInBackground` / `backgroundAudio`. Coming back resumes
/// nothing on its own.
final class DwMedia extends DwFlutterPlugin with WidgetsBindingObserver {
  DwMedia({this.config = const DwMediaConfig()})
    : sessionManager = DwMediaSessionManager(config: config);

  /// The project-wide defaults, each overridable per [open].
  final DwMediaConfig config;

  final DwMediaSessionManager sessionManager;

  @override
  bool get blocksStartup => false;

  @override
  Future<void> init(DwFlutterToolbox core) async {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Opens [items] as a new session — see [DwMediaSessionManager.open].
  DwMediaSession open({
    required List<DwMediaItem> items,
    int startIndex = 0,
    DwMediaCallbacks callbacks = const DwMediaCallbacks(),
    DwMediaOpenOptions? options,
  }) => sessionManager.open(
    items: items,
    startIndex: startIndex,
    callbacks: callbacks,
    options: options,
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        for (final session in sessionManager.sessions) {
          _toBackground(session);
        }
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _toBackground(DwMediaSession session) {
    if (session.isDisposed) return;
    final options = session.options;
    if (options.resume?.saveOnBackground ?? false) {
      unawaited(session.controller.savePosition());
    }
    if (!session.playback.value.isPlaying) return;
    final pause = switch (session.currentItem.kind) {
      DwMediaKind.video => options.pauseVideoInBackground,
      DwMediaKind.audio => !options.backgroundAudio,
    };
    if (pause) unawaited(session.pause());
  }

  /// Ends every session and stops watching the app's lifecycle.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await sessionManager.dispose();
  }
}

/// `dw.plugins.media`.
extension DwMediaAccess on DwPluginRegistry {
  DwMedia get media => of<DwMedia>();
}
