import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../config/dw_media_config.dart';
import '../controller/dw_media_controller.dart';
import '../controller/dw_media_controller_factory.dart';
import '../controller/dw_video_media_controller.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import '../model/dw_media_playback_state.dart';
import '../platform/dw_media_platform.dart';
import 'dw_media_queue_state.dart';

part 'dw_media_session.dart';

/// Every `DwMediaSession` the app has open — held by `DwMedia`, reached as
/// `dw.plugins.media.sessionManager`.
///
/// [active] is the session opened or played last: the one
/// `DwMiniPlayerHost` shows while it is minimized. Under
/// `DwMediaConfig.singleActiveItem`, opening or playing a session pauses
/// every other one.
final class DwMediaSessionManager {
  DwMediaSessionManager({required this.config});

  /// The plugin's defaults; each session lays its `DwMediaOpenOptions` over
  /// them.
  final DwMediaConfig config;

  final ValueNotifier<DwMediaSession?> active = ValueNotifier(null);

  final List<DwMediaSession> _sessions = [];

  /// The person's last mute choice, under `DwMediaConfig.rememberSound`.
  bool? _rememberedMuted;

  /// Every open session.
  List<DwMediaSession> get sessions => List.unmodifiable(_sessions);

  /// Opens [items] as a new session, starting at [startIndex].
  DwMediaSession open({
    required List<DwMediaItem> items,
    int startIndex = 0,
    DwMediaCallbacks callbacks = const DwMediaCallbacks(),
    DwMediaOpenOptions? options,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'a session needs an item');
    }
    RangeError.checkValidIndex(startIndex, items, 'startIndex');
    final session = DwMediaSession._(
      items: items,
      startIndex: startIndex,
      callbacks: callbacks,
      options: config.merge(options),
      manager: this,
    );
    _sessions.add(session);
    _claim(session);
    return session;
  }

  void _claim(DwMediaSession session) {
    active.value = session;
    if (!session.options.singleActiveItem) return;
    for (final other in _sessions) {
      if (!identical(other, session) && !other.isDisposed) {
        unawaited(other.pause());
      }
    }
  }

  void _release(DwMediaSession session) {
    if (identical(active.value, session)) active.value = null;
  }

  void _remove(DwMediaSession session) {
    _sessions.remove(session);
    _release(session);
  }

  /// Ends every open session — `DwMedia`'s own teardown.
  Future<void> dispose() async {
    for (final session in List.of(_sessions)) {
      await session.dispose();
    }
  }
}
