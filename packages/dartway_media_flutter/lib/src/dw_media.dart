import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';

import 'config/dw_media_config.dart';
import 'model/dw_media_callbacks.dart';
import 'model/dw_media_item.dart';
import 'session/dw_media_session.dart';
import 'session/dw_media_session_manager.dart';

/// A video/audio player for a DartWay app — `dw.plugins.media`.
///
/// Mechanism only: no colours, no icons, no built-in controls (see
/// `docs/3-flutter/ui-kit.md` on why DartWay ships no design). The default
/// controls a project actually shows live in its own `ui_kit/` — copy them
/// from `example/` (the `dartway-media` toolkit skill walks through it) and
/// restyle them; this package only makes them possible.
///
/// ```dart
/// dw = DwFlutterToolbox(
///   plugins: [DwMedia(config: DwMediaConfig(speeds: [1.0, 1.5, 2.0]))],
/// );
///
/// final session = dw.plugins.media.open(
///   items: [DwMediaItem(id: 'lesson-1', kind: DwMediaKind.video, source: DwMediaSource.url(url))],
/// );
/// ```
///
/// **The plugin owns the session**, not the widget that opened it: a
/// `DwMediaSession` survives the widget tree being torn down and rebuilt,
/// which is what lets the mini-player and fullscreen keep playing without
/// reloading. `DwMediaSessionManager.active` is what `DwMiniPlayerHost`
/// watches.
final class DwMedia extends DwFlutterPlugin with WidgetsBindingObserver {
  DwMedia({this.config = const DwMediaConfig()});

  /// The project-wide default — every field also overridable per
  /// [open] with a [DwMediaOpenOptions].
  final DwMediaConfig config;

  late final DwMediaSessionManager sessionManager = DwMediaSessionManager(
    config: config,
  );

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

  /// Pauses on the app going to the background — `paused`/`hidden`/
  /// `detached` — never on `inactive`: it fires for a system dialog, an
  /// incoming call banner or entering the OS's own fullscreen transition, and
  /// pausing on it broke a project's fullscreen video in practice (see
  /// `docs/3-flutter/media.md`). `resumed` does not auto-resume — the app
  /// decides that, same as "resume or start over" on open.
  ///
  /// Applied to every open session (`DwMediaConfig.pauseVideoInBackground`,
  /// `backgroundAudio`), not only the active one — a project with several
  /// sessions open (`singleActiveItem: false`) wants every video paused in
  /// the background, not just the foreground one.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        for (final session in sessionManager.sessions) {
          if (session.isDisposed) continue;
          if (!session.controller.state.value.isPlaying) continue;
          final item = session.currentItem;
          final shouldPause = switch (item.kind) {
            DwMediaKind.video => session.options.pauseVideoInBackground,
            DwMediaKind.audio => !session.options.backgroundAudio,
          };
          if (shouldPause) unawaited(session.pause());
        }
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await sessionManager.dispose();
  }
}

/// `dw.plugins.media`.
extension DwMediaAccess on DwPluginRegistry {
  DwMedia get media => of<DwMedia>();
}
