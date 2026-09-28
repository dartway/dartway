import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// A minimal `wakelock_plus` platform for tests — assign it to
/// `wakelockPlusPlatformInstance` (from `package:wakelock_plus/wakelock_plus.dart`)
/// to observe `DwWakelockCoordinator`'s calls without a real platform channel.
final class DwFakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool isEnabled = false;
  int toggleCount = 0;

  @override
  Future<void> toggle({required bool enable}) async {
    toggleCount++;
    isEnabled = enable;
  }

  @override
  Future<bool> get enabled async => isEnabled;
}
