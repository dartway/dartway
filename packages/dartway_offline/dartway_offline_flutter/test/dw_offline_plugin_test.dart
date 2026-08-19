import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_offline_flutter/dartway_offline_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dwInstance = DwFlutter(config: const DwConfig());

  group('DwOfflinePlugin', () {
    test('initializes its mobile runtime only once', () async {
      final runtime = _RecordingRuntime();
      var nativeFactoryCalls = 0;
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: () {
            nativeFactoryCalls += 1;
            return runtime;
          },
        ),
      );

      await plugin.init(dwInstance);
      await plugin.init(dwInstance);

      expect(nativeFactoryCalls, 1);
      expect(runtime.initializeCalls, 1);
      expect(plugin.status, DwOfflineStatus.available);
    });

    test('rejects a blank user scope before plugin mutation', () async {
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: _RecordingRuntime.new,
        ),
      );

      expect(() => DwOfflineUserScope(userScopeId: '  '), throwsArgumentError);
      expect(plugin.status, DwOfflineStatus.uninitialized);
      expect(plugin.activeUserScope, isNull);
    });

    test('activates a valid stable user scope after initialization', () async {
      final runtime = _RecordingRuntime();
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.ios,
          nativeRuntimeFactory: () => runtime,
        ),
      );
      final userScope = DwOfflineUserScope(userScopeId: ' profile-42 ');

      await plugin.init(dwInstance);
      await plugin.activateUserScope(userScope);

      expect(plugin.status, DwOfflineStatus.active);
      expect(
        plugin.activeUserScope,
        DwOfflineUserScope(userScopeId: 'profile-42'),
      );
      expect(runtime.activatedScopes, [userScope]);
    });

    test('does not expose a scope when runtime activation fails', () async {
      final runtime = _RecordingRuntime()
        ..activationFailure = StateError('activation failed');
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: () => runtime,
        ),
      );
      final userScope = DwOfflineUserScope(userScopeId: 'profile-a');

      await plugin.init(dwInstance);

      await expectLater(plugin.activateUserScope(userScope), throwsStateError);

      expect(runtime.activatedScopes, [userScope]);
      expect(plugin.activeUserScope, isNull);
      expect(plugin.status, DwOfflineStatus.available);
    });

    test(
      'purges the previous scope before the next scope becomes observable',
      () async {
        final runtime = _RecordingRuntime()..holdPurge = true;
        final plugin = DwOfflinePlugin(
          config: DwOfflineConfig(
            platformDetector: () => DwOfflinePlatform.android,
            nativeRuntimeFactory: () => runtime,
          ),
        );
        final firstScope = DwOfflineUserScope(userScopeId: 'profile-a');
        final nextScope = DwOfflineUserScope(userScopeId: 'profile-b');

        await plugin.init(dwInstance);
        await plugin.activateUserScope(firstScope);
        final switching = plugin.activateUserScope(nextScope);

        await runtime.purgeStarted.future;
        expect(runtime.purgedScopes, [firstScope]);
        expect(plugin.activeUserScope, isNull);

        runtime.completePurge();
        await switching;

        expect(plugin.activeUserScope, nextScope);
        expect(plugin.status, DwOfflineStatus.active);
      },
    );

    test('surfaces purge failure without activating the next scope', () async {
      final runtime = _RecordingRuntime()
        ..purgeFailure = StateError('purge failed');
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: () => runtime,
        ),
      );

      await plugin.init(dwInstance);
      await plugin.activateUserScope(
        DwOfflineUserScope(userScopeId: 'profile-a'),
      );

      await expectLater(
        plugin.activateUserScope(DwOfflineUserScope(userScopeId: 'profile-b')),
        throwsStateError,
      );

      expect(plugin.activeUserScope, isNull);
      expect(plugin.status, DwOfflineStatus.available);
    });

    test('retries failed scope cleanup before any later activation', () async {
      final runtime = _RecordingRuntime()
        ..purgeFailure = StateError('purge failed');
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: () => runtime,
        ),
      );
      final firstScope = DwOfflineUserScope(userScopeId: 'profile-a');
      final failedNextScope = DwOfflineUserScope(userScopeId: 'profile-b');
      final laterScope = DwOfflineUserScope(userScopeId: 'profile-c');

      await plugin.init(dwInstance);
      await plugin.activateUserScope(firstScope);

      await expectLater(
        plugin.activateUserScope(failedNextScope),
        throwsStateError,
      );
      await expectLater(plugin.activateUserScope(laterScope), throwsStateError);

      expect(runtime.purgedScopes, [firstScope, firstScope]);
      expect(plugin.activeUserScope, isNull);
      expect(plugin.status, DwOfflineStatus.available);

      runtime.purgeFailure = null;
      await plugin.activateUserScope(laterScope);

      expect(runtime.purgedScopes, [firstScope, firstScope, firstScope]);
      expect(plugin.activeUserScope, laterScope);
      expect(plugin.status, DwOfflineStatus.active);
    });

    test(
      'deactivation purges the active scope and remains initialized',
      () async {
        final runtime = _RecordingRuntime();
        final plugin = DwOfflinePlugin(
          config: DwOfflineConfig(
            platformDetector: () => DwOfflinePlatform.android,
            nativeRuntimeFactory: () => runtime,
          ),
        );
        final userScope = DwOfflineUserScope(userScopeId: 'profile-42');

        await plugin.init(dwInstance);
        await plugin.activateUserScope(userScope);
        await plugin.deactivateUserScope();

        expect(runtime.purgedScopes, [userScope]);
        expect(plugin.activeUserScope, isNull);
        expect(plugin.status, DwOfflineStatus.available);
      },
    );

    test(
      'dispose detaches listeners, clears state, and is idempotent',
      () async {
        final runtime = _RecordingRuntime();
        var listenerDetachCalls = 0;
        final plugin = DwOfflinePlugin(
          config: DwOfflineConfig(
            platformDetector: () => DwOfflinePlatform.android,
            nativeRuntimeFactory: () => runtime,
            detachLifecycleListeners: () async {
              listenerDetachCalls += 1;
            },
          ),
        );

        await plugin.init(dwInstance);
        await plugin.activateUserScope(
          DwOfflineUserScope(userScopeId: 'profile-42'),
        );
        await plugin.dispose();
        await plugin.dispose();

        expect(listenerDetachCalls, 1);
        expect(runtime.disposeCalls, 1);
        expect(runtime.deactivatedScopes, [
          DwOfflineUserScope(userScopeId: 'profile-42'),
        ]);
        expect(runtime.purgedScopes, isEmpty);
        expect(plugin.activeUserScope, isNull);
        expect(plugin.status, DwOfflineStatus.disposed);
      },
    );

    test('retries failed runtime deactivation before disposing', () async {
      final runtime = _RecordingRuntime()
        ..deactivationFailure = StateError('deactivation failed');
      var listenerDetachCalls = 0;
      final plugin = DwOfflinePlugin(
        config: DwOfflineConfig(
          platformDetector: () => DwOfflinePlatform.android,
          nativeRuntimeFactory: () => runtime,
          detachLifecycleListeners: () async {
            listenerDetachCalls += 1;
          },
        ),
      );
      final userScope = DwOfflineUserScope(userScopeId: 'profile-a');

      await plugin.init(dwInstance);
      await plugin.activateUserScope(userScope);

      await expectLater(plugin.dispose(), throwsStateError);

      expect(runtime.deactivatedScopes, [userScope]);
      expect(runtime.purgedScopes, isEmpty);
      expect(runtime.disposeCalls, 0);
      expect(listenerDetachCalls, 0);
      expect(plugin.activeUserScope, userScope);
      expect(plugin.status, DwOfflineStatus.active);

      runtime.deactivationFailure = null;
      await plugin.dispose();

      expect(runtime.deactivatedScopes, [userScope, userScope]);
      expect(runtime.purgedScopes, isEmpty);
      expect(runtime.disposeCalls, 1);
      expect(listenerDetachCalls, 1);
      expect(plugin.status, DwOfflineStatus.disposed);
    });

    test(
      'reports unsupported platforms as disabled without creating native runtime',
      () async {
        var nativeFactoryCalls = 0;
        final plugin = DwOfflinePlugin(
          config: DwOfflineConfig(
            platformDetector: () => DwOfflinePlatform.web,
            nativeRuntimeFactory: () {
              nativeFactoryCalls += 1;
              return _RecordingRuntime();
            },
          ),
        );

        await plugin.init(dwInstance);

        expect(plugin.status, DwOfflineStatus.disabled);
        expect(nativeFactoryCalls, 0);
      },
    );
  });
}

class _RecordingRuntime implements DwOfflineRuntime {
  int initializeCalls = 0;
  int disposeCalls = 0;
  bool holdPurge = false;
  Object? activationFailure;
  Object? deactivationFailure;
  Object? purgeFailure;
  final activatedScopes = <DwOfflineUserScope>[];
  final deactivatedScopes = <DwOfflineUserScope>[];
  final purgedScopes = <DwOfflineUserScope>[];
  final purgeStarted = Completer<void>();
  Completer<void>? _purgeCompletion;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<void> activateUserScope(DwOfflineUserScope userScope) async {
    activatedScopes.add(userScope);
    if (activationFailure != null) {
      throw activationFailure!;
    }
  }

  @override
  Future<void> deactivateUserScope(DwOfflineUserScope userScope) async {
    deactivatedScopes.add(userScope);
    if (deactivationFailure != null) {
      throw deactivationFailure!;
    }
  }

  @override
  Future<void> purgeUserScope(DwOfflineUserScope userScope) async {
    purgedScopes.add(userScope);
    if (!purgeStarted.isCompleted) {
      purgeStarted.complete();
    }
    if (holdPurge) {
      _purgeCompletion = Completer<void>();
      await _purgeCompletion!.future;
    }
    if (purgeFailure != null) {
      throw purgeFailure!;
    }
  }

  void completePurge() {
    _purgeCompletion!.complete();
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}
