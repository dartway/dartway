import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/session/domain/dw_session_state_model.dart';
import '../app/session/service/dw_session_service.dart';
import '../app/session/state/dw_session_state_notifier.dart';
import '../app/session/state/dw_user_profile_providers.dart';
import '../app/socket/service/dw_socket_service.dart';
import '../private/dw_singleton.dart';
import '../repository/dw_repository.dart';

class DwCore<
  ServerpodClientClass extends ServerpodClientShared,
  UserProfileClass extends SerializableModel
>
    extends DwFlutter {
  final ServerpodClientClass? _client;

  /// This app's own generated Serverpod client — for the endpoints the app
  /// declared itself. DartWay's own CRUD does not travel through it; that is
  /// [serverTransport].
  ///
  /// Throws when the core was built without one, which only happens in a test
  /// that passed a `transport` instead. An application always has a client, so
  /// this stays non-nullable and `dw.client` needs no `!`.
  ServerpodClientClass get client {
    final client = _client;
    if (client == null) {
      throw StateError(
        'DwCore was built without a Serverpod client.\n'
        'Only a test does that (it passed transport: instead). Application '
        'code reaching dw.client means the core was built the wrong way.',
      );
    }
    return client;
  }

  final DwAlerts dwAlerts;
  late final DwSessionService<UserProfileClass>? sessionService;
  late final DwSocketService? socketService;
  late final NotifierProvider<
    DwSessionStateNotifier<UserProfileClass>,
    DwSessionStateModel<UserProfileClass>
  >?
  sessionProvider;

  /// Built on first read rather than in the constructor: an app that never asks
  /// for the profile never gets the providers. [sessionProvider] is assigned by
  /// then — the constructor has to have finished for anyone to reach this.
  late final DwUserProfileProviders<UserProfileClass> _userProfileProviders =
      DwUserProfileProviders<UserProfileClass>(sessionProvider);

  /// The signed-in profile, or `null` while signed out, before the session is
  /// initialized, or when the app runs without an auth key manager at all.
  ///
  /// Typed by this core's `UserProfileClass`, so an app reads its own model out
  /// of it without declaring a provider of its own. Use it where the user may
  /// legitimately be absent — a splash screen, a router guard, the auth zone.
  /// Under an authenticated subtree reach for [requireUserProfileProvider]
  /// instead and stop writing `!`.
  Provider<UserProfileClass?> get userProfileProvider =>
      _userProfileProviders.userProfile;

  /// The signed-in profile as a non-nullable value, for everything drawn under
  /// an authenticated subtree (see `DwUserAsyncScope`).
  ///
  /// Throws when nobody is signed in — that is a wiring mistake, not a state to
  /// render, and the message says where to look. (A [StateError], reaching the
  /// reader inside Riverpod's own `ProviderException`.) Being non-nullable it
  /// also makes `.select` usable:
  /// `ref.watch(dw.requireUserProfileProvider.select((p) => p.name))`.
  Provider<UserProfileClass> get requireUserProfileProvider =>
      _userProfileProviders.requireUserProfile;

  /// The signed-in user id, or `null` while signed out — and `null` as well when
  /// the app runs without a DartWay session at all (its client carries a key
  /// manager of its own).
  ///
  /// Read it where the id is all you need — a filter, a channel key, an
  /// ownership check — instead of pulling the whole profile out of
  /// [userProfileProvider] to reach `.id`.
  Provider<int?> get signedInUserIdProvider =>
      _userProfileProviders.signedInUserId;

  /// The wire `dw.repo` speaks — the single path every CRUD call, realtime
  /// subscription and upload takes to the server.
  ///
  /// An app reads and writes through `dw.repo` and never needs this. Reach for
  /// it in the two cases the repository cannot cover: a test substitutes it
  /// (`DwRecordingServerTransport` from
  /// `package:dartway_serverpod_core_flutter/testing.dart`), and a dev stand
  /// exercises a DartWay endpoint deliberately.
  final DwServerTransport serverTransport;

  final int? Function(UserProfileClass? user) getUserId;

  /// Optional outbound hook fired whenever the realtime status changes.
  /// Default `null` (no-op) — apps may wire it to their own status UI or
  /// telemetry. Connection-level retry errors are swallowed internally and
  /// never reach the global error handler.
  final void Function(DwSocketStatus status)? onSocketStatusChanged;

  static ServerpodClientShared _requireClient(ServerpodClientShared? client) {
    if (client == null) {
      throw ArgumentError(
        'DwCore has no way to reach the server.\n'
        'Pass client: <your generated Client>, or — from a test — '
        'transport: DwRecordingServerTransport(...).',
      );
    }
    return client;
  }

  /// Builds the core.
  ///
  /// [client] is this app's generated Serverpod client, and is what an
  /// application always passes: the DartWay CRUD transport is derived from it.
  /// [transport] replaces that derivation — pass it *instead of* [client] in a
  /// test, so nothing has to stand up a Serverpod client to see a widget draw
  /// or a save leave. Exactly one of the two is required; when both are given
  /// [transport] wins and [client] stays reachable as `dw.client`.
  DwCore({
    required super.config,
    ServerpodClientClass? client,
    DwServerTransport? transport,
    required this.dwAlerts,
    required this.getUserId,
    super.plugins,
    this.onSocketStatusChanged,
  }) : _client = client,
       // In the initializer list, so a core with neither is refused *before*
       // the superclass claims the ambient `dw` — a half-built core registered
       // as the one and only is worse than the error that produced it.
       serverTransport =
           transport ?? DwServerpodTransport(_requireClient(client)) {
    setDwInstance(this);

    DwCoreServerpodClient.protocol = serverTransport.serializationManager;

    socketService = DwSocketService(
      openChannelStream: (channel) =>
          serverTransport.subscribeOnUpdates(channel: channel),
      reportError: handleError,
      onStatusChanged: onSocketStatusChanged,
      // The server ended this app's subscriptions because the account is no
      // longer allowed to act. Nothing is retried and no key is deleted — the
      // server already took it — the local session simply ends, so the user
      // lands on the sign-in screen instead of watching realtime go quiet.
      onAuthenticationRevoked: () =>
          unawaited(sessionService?.invalidateSession() ?? Future.value()),
    );

    final keyProvider = _client?.authKeyProvider;

    if (keyProvider is DwAuthenticationKeyManager) {
      int? socketUserId;
      sessionService = DwSessionService<UserProfileClass>(
        keyManager: keyProvider,
        onUserChanged: (_, id) {
          final previousUserId = socketUserId;
          socketUserId = id;
          socketService!.onUserChanged(previousUserId, id);
        },
        // Doubles as the session check on startup: the internal profile config
        // filters by the authenticated user, so an empty answer means the
        // stored key no longer identifies this user — see [DwSessionService].
        fetchUserProfile: (userId) async {
          final response = await serverTransport.getOne(
            className: DwRepository.typeName<UserProfileClass>(),
            filter: DwBackendFilter<int>.value(
              type: DwBackendFilterType.equals,
              fieldName: 'id',
              fieldValue: userId,
            ),
            apiGroup: DwCoreConst.dartwayInternalApi,
          );

          final wrapper = DwRepository.processApiResponse<DwModelWrapper?>(
            response,
          );

          return wrapper?.model as UserProfileClass?;
        },
        deleteAuthKey: (authKeyId) async {
          await serverTransport.delete(
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

  /// The single client-side data-access point — reads (providers), writes and
  /// realtime — reached as `dw.repo`.
  DwRepo get repo => const DwRepo();

  /// Out-of-the-box alerting: unless the app installed its own error policy
  /// in [DwConfig], every reported error goes to [dwAlerts] enriched with the
  /// app-state context (route, mounted features, action/call, user).
  /// Connection blips are UX, not alerts — they are filtered out here, and so
  /// are refusals, which are answers ([DwRefusal]).
  @override
  void dispatchReport(DwErrorReport report) {
    if (hasCustomErrorHandling) return super.dispatchReport(report);

    // A rule saying no is not an incident. It has already reached the user in
    // its own words through `dw.action`; alerting it as well was how twenty
    // ordinary refusals became twenty pages in two days.
    if (report.error is DwRefusal) return;

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
    DwErrorSource.uiAction =>
      report.actionLabel == null
          ? 'UI action failed'
          : 'Action failed: ${report.actionLabel}',
    DwErrorSource.asyncBuild => 'Async build error',
    DwErrorSource.failedCall =>
      report.failedCall == null
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
