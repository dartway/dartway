import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as dartway;
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/session/domain/dw_session_state_model.dart';
import '../app/session/service/dw_session_service.dart';
import '../app/session/state/dw_session_state_notifier.dart';
import '../app/socket/service/dw_socket_service.dart';
import '../private/dw_singleton.dart';
import '../utils/dw_error_report_alert_mapping.dart';

class DwCore<
  ServerpodClientClass extends ServerpodClientShared,
  UserProfileClass extends SerializableModel
>
    extends DwFlutter {
  final ServerpodClientClass client;
  final DwAlerts dwAlerts;
  late final DwSessionService<UserProfileClass>? sessionService;
  late final DwSocketService? socketService;
  late final NotifierProvider<
    DwSessionStateNotifier<UserProfileClass>,
    DwSessionStateModel<UserProfileClass>
  >?
  sessionProvider;

  late final dartway.Caller endpointCaller;

  final int? Function(UserProfileClass? user) getUserId;

  /// Optional outbound hook fired whenever the streaming connection status
  /// changes. Default `null` (no-op) — apps may wire it to their own status UI
  /// or telemetry. Connection-level retry errors are swallowed internally and
  /// never reach the global error handler.
  final void Function(dartway.StreamingConnectionStatus status)?
  onStreamingStatusChanged;

  DwCore({
    required super.config,
    required this.client,
    required this.dwAlerts,
    required this.getUserId,
    super.plugins,
    this.onStreamingStatusChanged,
  }) {
    setDwInstance(this);

    DwCoreServerpodClient.protocol = client.serializationManager;

    final dartwayCaller = client.moduleLookup.values.firstWhereOrNull(
      (e) => e is dartway.Caller,
    );

    if (dartwayCaller == null) {
      throw Exception(
        'DartWay Core module not found. '
        'Add dartway_serverpod_core module to the client.',
      );
    }
    endpointCaller = dartwayCaller as dartway.Caller;
    socketService = DwSocketService(onStatusChanged: onStreamingStatusChanged);

    final keyProvider = client.authKeyProvider;

    if (keyProvider is DwAuthenticationKeyManager) {
      int? socketUserId;
      sessionService = DwSessionService<UserProfileClass>(
        keyManager: keyProvider,
        onUserChanged: (_, id) {
          final previousUserId = socketUserId;
          socketUserId = id;
          socketService!.onUserChanged(previousUserId, id);
        },
        fetchUserProfile: (userId) async {
          final response = await endpointCaller.dwCrud.getOne(
            className: DwRepository.typeName<UserProfileClass>(),
            filter: DwBackendFilter<int>.value(
              type: DwBackendFilterType.equals,
              fieldName: 'id',
              fieldValue: userId,
            ),
            apiGroup: DwCoreConst.dartwayInternalApi,
          );

          DwRepository.processApiResponse<DwModelWrapper?>(response);
        },
        deleteAuthKey: (authKeyId) async {
          await endpointCaller.dwCrud.delete(
            className: 'DwAuthKey',
            modelId: authKeyId,
            apiGroup: DwCoreConst.dartwayInternalApi,
          );
        },
      );
      sessionProvider =
          NotifierProvider<
            DwSessionStateNotifier<UserProfileClass>,
            DwSessionStateModel<UserProfileClass>
          >(DwSessionStateNotifier<UserProfileClass>.new);
    } else {
      sessionProvider = null;
      sessionService = null;
    }
  }

  /// Out-of-the-box alerting: unless the app installed its own error policy
  /// in [DwConfig], every reported error goes to [dwAlerts] enriched with the
  /// app-state context (route, mounted features, action/call, user).
  /// Connection blips are UX, not alerts — they are filtered out here.
  @override
  void reportError(DwErrorReport report) {
    if (hasCustomErrorHandling) return super.reportError(report);

    if (isStreamingConnectionError(report.error)) return;

    // A failed server call surfaces twice: onFailedCall first (with
    // endpoint.method attached), then the rethrow inside the calling action —
    // only the first, richest report goes out.
    if (_recentlyReported(report.error)) return;

    if (kDebugMode) {
      debugPrint('[DwCore] ${report.error}\n${report.stackTrace}');
    }

    dwAlerts.reportError(
      _alertTitle(report),
      exception: report.error,
      stackTrace: report.stackTrace,
      context: report.toAlertContext(
        userLabel: switch (sessionService?.currentUserId) {
          null => null,
          final id => 'user $id',
        },
      ),
    );
  }

  static const _dedupWindow = Duration(seconds: 2);
  final _recentErrors = <(Object, DateTime)>[];

  bool _recentlyReported(Object error) {
    final now = DateTime.now();
    _recentErrors.removeWhere(
      (entry) => now.difference(entry.$2) > _dedupWindow,
    );
    if (_recentErrors.any((entry) => identical(entry.$1, error))) return true;
    _recentErrors.add((error, now));
    if (_recentErrors.length > 5) _recentErrors.removeAt(0);
    return false;
  }

  static String _alertTitle(DwErrorReport report) => switch (report.source) {
        DwErrorSource.zone => 'Unhandled error',
        DwErrorSource.uiAction => report.actionLabel == null
            ? 'UI action failed'
            : 'Action failed: ${report.actionLabel}',
        DwErrorSource.asyncBuild => 'Async build error',
        DwErrorSource.failedCall => report.failedCall == null
            ? 'Server call failed'
            : 'Failed call: ${report.failedCall}',
        DwErrorSource.manual => 'Reported error',
      };

  Future<void> initDwCore({
    // TODO: remove initRepositoryFunction
    required Function() initRepositoryFunction,
  }) async {
    await super.init();

    await initRepositoryFunction();
    DwRepository.setupRepository(
      defaultModel: DwAuthKey(
        id: DwRepository.mockModelId,
        userId: DwRepository.mockModelId,
        key: 'mockKey',
        hash: 'mockHash',
      ),
    );
    DwRepository.setupRepository(
      defaultModel: DwAuthData(
        userProfile: DwRepository.getDefault<UserProfileClass>(),
        userId: DwRepository.mockModelId,
        key: 'mockKey',
        keyId: DwRepository.mockModelId,
      ),
    );

    // TODO: check if this is needed and actally works
    final defaultModels = <Type, SerializableModel>{
      UserProfileClass: DwRepository.getDefault<UserProfileClass>(),
    };

    for (final entry in defaultModels.entries) {
      DwRepository.setupRepository(defaultModel: entry.value);
    }

    if (sessionService != null) {
      await sessionService!.initialize();
    }

    socketService!.init();

    if (kDebugMode) {
      debugPrint('[DwCore] initialized for $UserProfileClass');
    }
  }
}
