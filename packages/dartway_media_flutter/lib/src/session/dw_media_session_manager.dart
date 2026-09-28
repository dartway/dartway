import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

part '../fullscreen/dw_media_fullscreen_host.dart';
part 'dw_media_when_unlocked.dart';
part 'dw_media_session.dart';

/// Every `DwMediaSession` the app has open — held by `DwMedia`, reached as
/// `dw.plugins.media.sessionManager`.
///
/// [active] is the session the mini-player shows: the one played last, or
/// opened last while nothing else plays. Under
/// `DwMediaConfig.singleActiveItem`, playing a session pauses every other.
final class DwMediaSessionManager {
  DwMediaSessionManager({required this.config})
    : assert(
        config.speedsHoldDefault,
        'defaultSpeed ${config.defaultSpeed} is not one of speeds '
        '${config.speeds}',
      );

  /// The plugin's defaults; each session lays its `DwMediaOpenOptions` over
  /// them.
  final DwMediaConfig config;

  final ValueNotifier<DwMediaSession?> _active = ValueNotifier(null);

  final List<DwMediaSession> _sessions = [];

  /// The person's last mute choice, under `DwMediaConfig.rememberSound`.
  bool? _rememberedMuted;

  bool _inBackground = false;

  ValueListenable<DwMediaSession?> get active => _active;

  /// Every open session.
  List<DwMediaSession> get sessions => List.unmodifiable(_sessions);

  /// Opens [items] as a session, starting at [startIndex].
  ///
  /// **One item, one engine**: when a session still open stands on the same
  /// item — the one the mini-player shows, one the mini-player's close only
  /// hid — that session is returned instead of a second engine, and this
  /// open's request applies to it: [callbacks] replace the old ones, the
  /// settings resolved from [options] replace the old ones (those only a
  /// load applies — the start speed, the web's muted start, the iOS
  /// display-sleep option — stay as the item was loaded), a different
  /// queue replaces the old one around the same item, and `autoplayOnOpen`
  /// plays it if it is paused or hidden.
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
    final wanted = items[startIndex];
    final resolved = config.merge(options);
    for (final session in _sessions) {
      if (!session.isDisposed && session.currentItem == wanted) {
        session._hidden = false;
        session._reopen(
          items: items,
          startIndex: startIndex,
          callbacks: callbacks,
          options: resolved,
        );
        final current = _active.value;
        if (current == null || !current.playback.value.isPlaying) {
          _active.value = session;
        }
        return session;
      }
    }
    _endHidden();
    final session = DwMediaSession._(
      items: items,
      startIndex: startIndex,
      callbacks: callbacks,
      options: resolved,
      manager: this,
    );
    _sessions.add(session);
    // Autoplay claims the session through `play()`. Without it the new
    // session takes the mini-player's place only while nothing plays.
    if (!session.options.autoplayOnOpen) {
      final current = _active.value;
      if (current == null || !current.playback.value.isPlaying) {
        _active.value = session;
      }
    }
    session._open(autoplay: session.options.autoplayOnOpen);
    return session;
  }

  /// A session the mini-player's close only hid is reachable by opening its
  /// item again — until another session opens, when nothing could reach it
  /// any more and its engine goes.
  void _endHidden() {
    for (final session in List.of(_sessions)) {
      if (session._hidden) unawaited(session.dispose());
    }
  }

  void _claim(DwMediaSession session) {
    _active.value = session;
    if (!session.options.singleActiveItem) return;
    for (final other in _sessions) {
      if (!identical(other, session) && !other.isDisposed) {
        unawaited(other.pause());
      }
    }
  }

  void _release(DwMediaSession session) {
    _whenUnlocked(() {
      if (identical(_active.value, session)) _active.value = null;
    });
  }

  void _remove(DwMediaSession session) {
    _sessions.remove(session);
    _release(session);
  }

  /// What `DwMedia` forwards from the app's lifecycle: the background is
  /// `hidden`, `paused` and `detached` — never `inactive`, which a system
  /// sheet or a permission prompt raises too.
  @internal
  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_inBackground) return;
        _inBackground = true;
        for (final session in List.of(_sessions)) {
          session._toBackground();
        }
      case AppLifecycleState.resumed:
        _inBackground = false;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Ends every open session — `DwMedia`'s own teardown.
  Future<void> dispose() async {
    for (final session in List.of(_sessions)) {
      await session.dispose();
    }
  }
}
