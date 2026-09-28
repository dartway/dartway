import 'package:wakelock_plus/wakelock_plus.dart';

/// Refcounts every `DwVideoMediaController` that currently wants the screen
/// kept awake (`DwMediaConfig.wakelockWhilePlaying`), so
/// `WakelockPlus.toggle` is called only on the 0→1 and 1→0 transitions even
/// with several video sessions open at once.
///
/// A test substitutes `wakelockPlusPlatformInstance` from `package:wakelock_plus/wakelock_plus.dart`
/// rather than this class — there is nothing DartWay-specific to fake here.
final class DwWakelockCoordinator {
  DwWakelockCoordinator._();

  static final DwWakelockCoordinator instance = DwWakelockCoordinator._();

  final Set<Object> _wanters = {};

  /// Whether [owner] currently wants the wakelock held.
  Future<void> setWants(Object owner, bool wants) async {
    final before = _wanters.isNotEmpty;
    if (wants) {
      _wanters.add(owner);
    } else {
      _wanters.remove(owner);
    }
    final after = _wanters.isNotEmpty;
    if (before == after) return;
    await WakelockPlus.toggle(enable: after);
  }

  /// Test-only: drops every wanter without calling [WakelockPlus.toggle] —
  /// tests that create controllers without awaiting `dispose` would otherwise
  /// leak a "wants" entry into the next test.
  void resetForTest() => _wanters.clear();
}
