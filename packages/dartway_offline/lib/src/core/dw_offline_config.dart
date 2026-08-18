import 'dw_offline_user_scope.dart';

/// The target platform relevant to the optional offline runtime.
enum DwOfflinePlatform { android, ios, web, windows, macos, linux }

/// The consumer-visible lifecycle capability of the offline plugin.
enum DwOfflineStatus { uninitialized, available, active, disabled, disposed }

/// Storage, downloader, and repository lifecycle owned by the offline plugin.
abstract interface class DwOfflineRuntime {
  Future<void> initialize();

  /// Makes [userScope] the only scope eligible for offline operations.
  Future<void> activateUserScope(DwOfflineUserScope userScope);

  /// Stops runtime access without deleting persisted offline content.
  Future<void> deactivateUserScope(DwOfflineUserScope userScope);

  /// Removes every protected artifact belonging to [userScope].
  Future<void> purgeUserScope(DwOfflineUserScope userScope);

  Future<void> dispose();
}

/// Configuration for a [DwOfflinePlugin].
///
/// Platform inspection and mobile runtime creation are injected so a consumer
/// can make deterministic tests and unsupported targets never touch a native
/// factory.
class DwOfflineConfig {
  const DwOfflineConfig({
    required this.platformDetector,
    required this.nativeRuntimeFactory,
    this.detachLifecycleListeners,
  });

  final DwOfflinePlatform Function() platformDetector;
  final DwOfflineRuntime Function() nativeRuntimeFactory;

  /// Detaches lifecycle listeners created by the host application, if any.
  final Future<void> Function()? detachLifecycleListeners;
}
