import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_callbacks.dart';
import '../model/dw_media_item.dart';
import 'dw_media_session.dart';

/// Owns every `DwMediaSession` a project opens, and — when
/// `DwMediaConfig.singleActiveItem` is on — the app-wide rule that starting
/// one pauses whatever else was playing.
///
/// `DwMedia` holds exactly one of these; `DwMiniPlayerHost` watches [active]
/// to know which session to show shrunk down.
final class DwMediaSessionManager {
  DwMediaSessionManager({required DwMediaConfig config}) : _config = config;

  final DwMediaConfig _config;

  /// The session `DwMiniPlayerHost` offers to show — the most recently opened
  /// or claimed one. Not necessarily playing (it may be paused) and not the
  /// only session that may exist: a project can hold onto a session it opened
  /// earlier and drive it directly without ever making it active again.
  final ValueNotifier<DwMediaSession?> active = ValueNotifier(null);

  final List<DwMediaSession> _sessions = [];

  /// Every session currently open — what the lifecycle observer walks to
  /// apply the background pause rules to all of them, not only [active].
  List<DwMediaSession> get sessions => List.unmodifiable(_sessions);

  /// Opens a queue as a new session, resolving [options] against the plugin's
  /// [DwMediaConfig]. When `DwMediaConfig.singleActiveItem` holds for the new
  /// session, whatever session was previously active is paused.
  DwMediaSession open({
    required List<DwMediaItem> items,
    int startIndex = 0,
    DwMediaCallbacks callbacks = const DwMediaCallbacks(),
    DwMediaOpenOptions? options,
  }) {
    assert(items.isNotEmpty, 'DwMedia.open requires at least one item');
    assert(
      startIndex >= 0 && startIndex < items.length,
      'startIndex out of range',
    );
    final resolved = _config.merge(options);
    final session = DwMediaSession.open(
      items: items,
      startIndex: startIndex,
      callbacks: callbacks,
      options: resolved,
      manager: this,
    );
    _sessions.add(session);
    if (resolved.singleActiveItem) claimActive(session);
    active.value = session;
    return session;
  }

  /// Makes [session] the active one, pausing whichever different session was
  /// active before — called by `DwMediaSession.play()` too, so resuming a
  /// session directly (without reopening it) still enforces the rule.
  void claimActive(DwMediaSession session) {
    final previous = active.value;
    active.value = session;
    if (previous != null && !identical(previous, session) && !previous.isDisposed) {
      unawaited(previous.pause());
    }
  }

  /// Drops [session] from [active] without touching its playback — used by
  /// `DwMediaSession.closeFromMiniPlayer` when closing only hides the
  /// mini-player rather than stopping the session.
  void forget(DwMediaSession session) {
    if (identical(active.value, session)) active.value = null;
  }

  void onSessionDisposed(DwMediaSession session) {
    _sessions.remove(session);
    if (identical(active.value, session)) active.value = null;
  }

  /// Disposes every open session — called by `DwMedia`'s own teardown; there
  /// is no ordinary app path that needs this; open sessions otherwise outlive
  /// the widget tree on purpose.
  Future<void> dispose() async {
    for (final session in List.of(_sessions)) {
      await session.dispose();
    }
  }
}
