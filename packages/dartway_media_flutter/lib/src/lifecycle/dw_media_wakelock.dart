import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

/// Holds the screen on while any video controller wants it
/// (`DwMediaConfig.wakelockWhilePlaying`), calling `wakelock_plus` only on
/// the first want and after the last: two sessions playing at once
/// (`singleActiveItem: false`) must not have one's pause release the other's
/// lock. Internal to the package.
final class DwWakelockCoordinator {
  DwWakelockCoordinator._();

  static final DwWakelockCoordinator instance = DwWakelockCoordinator._();

  final Set<Object> _wanters = {};

  /// Records whether [owner] wants the screen on. Never waits on the
  /// platform, and a platform without the plugin (a widget test) changes
  /// nothing but the lock itself.
  void setWants(Object owner, bool wants) {
    final before = _wanters.isNotEmpty;
    if (wants) {
      _wanters.add(owner);
    } else {
      _wanters.remove(owner);
    }
    final after = _wanters.isNotEmpty;
    if (before == after) return;
    unawaited(
      WakelockPlus.toggle(enable: after).catchError((Object _) {
        // No wakelock on this platform: playback goes on regardless.
      }),
    );
  }
}
