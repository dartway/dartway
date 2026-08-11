import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
import 'package:flutter/foundation.dart';

import '../../../repository/dw_repository.dart';
import '../domain/dw_socket_status.dart';
import 'dw_channel_subscriptions.dart';

/// The app's half of realtime: which channels it follows, and what arrives on
/// them.
///
/// Everything travels on method streams — one per channel, opened through
/// `dwCrud.subscribeOnUpdates` and refused by the server unless a
/// `DwChannelConfig` covers it. There is no connection to manage besides them:
/// Serverpod's client opens the socket with the first stream and closes it with
/// the last, so subscribing *is* connecting.
class DwSocketService {
  DwSocketService({
    required this.openChannelStream,
    required this.reportError,
    this.onStatusChanged,
    this.onAuthenticationRevoked,
  });

  /// Opens the server-side stream for a channel. Injected rather than reached
  /// for through the `dw` singleton, for the reason [DwSessionService] takes
  /// its own dependencies that way: what this service decides — see
  /// [_handleChannelClosedByServer] — is then testable without a booted client.
  final Stream<SerializableModel> Function(String channel) openChannelStream;

  /// Reports a bug in the app's channel declarations. Wired by `DwCore` to
  /// `dw.handleError`, and injected for the same reason as [openChannelStream].
  final void Function(Object error, StackTrace stackTrace) reportError;

  /// Optional outbound hook fired on every status change. Default is `null`
  /// (no-op) — the framework raises no alerts on its own.
  final void Function(DwSocketStatus status)? onStatusChanged;

  /// Called when the server ended this app's subscriptions because its
  /// authentication was revoked — the account was deleted, banned or signed out
  /// everywhere. Wired by `DwCore` to end the local session.
  final void Function()? onAuthenticationRevoked;

  /// Who the app is signed in as, as far as realtime is concerned — `null`
  /// while signed out. Kept because a refusal means opposite things on either
  /// side of it; see [_handleChannelClosedByServer].
  int? _signedInUserProfileId;

  late final _channelSubscriptions = DwChannelSubscriptions(
    openChannelStream: openChannelStream,
    onUpdate: _processUpdate,
    onStatusChanged: _handleStatusChanged,
    onChannelClosedByServer: _handleChannelClosedByServer,
  );

  final ValueNotifier<DwSocketStatus> statusNotifier = ValueNotifier(
    DwSocketStatus.idle,
  );

  void init() {
    _channelSubscriptions.start();
  }

  Future<void> dispose() async {
    await _channelSubscriptions.dispose();
  }

  /// Follows the signed-in user's own channel, and drops the previous user's.
  ///
  /// The framework subscribes to it rather than leaving it to the app: it is
  /// where `session.sendUpdatesToUser` delivers, so an app that forgot the
  /// subscription would lose every private update with nothing to show for it.
  /// The name is built from [DwCoreConst] on both sides, and the server hands
  /// it to no one but its owner.
  void onUserChanged(int? previousUserId, int? nextUserId) {
    if (previousUserId == nextUserId) return;

    // Set before the reopening below is scheduled, so a refusal caused by it is
    // judged against the session that will carry it, not the one that ended.
    _signedInUserProfileId = nextUserId;

    unawaited(_followUser(previousUserId, nextUserId));
  }

  Future<void> _followUser(int? previousUserId, int? nextUserId) async {
    if (previousUserId != null) {
      await unsubscribeFromChannel(
        DwCoreConst.userUpdatesChannel(previousUserId),
      );
    }

    if (nextUserId != null) {
      await subscribeToChannel(DwCoreConst.userUpdatesChannel(nextUserId));
    }

    // The app's own channels are kept, and reopened rather than left running: a
    // stream carries the authentication it was opened with, so one that
    // survives the switch would go on delivering the previous user's channel
    // into the next user's app. Reopening asks the server again, with the new
    // session — and a channel the new user may not follow is refused there
    // rather than assumed here.
    await _channelSubscriptions.reopenAll();
  }

  void _handleStatusChanged(DwSocketStatus status) {
    statusNotifier.value = status;
    onStatusChanged?.call(status);
  }

  void _handleChannelClosedByServer(
    String channel,
    DwChannelClosedReason reason,
  ) {
    switch (reason) {
      case DwChannelClosedReason.authenticationRevoked:
        debugPrint(
          '[DwSocketService] authentication revoked; ending the session',
        );
        // Every other channel is about to be refused for the same reason, and
        // the stored key is already gone from the server.
        unawaited(unsubscribeAllChannels());
        onAuthenticationRevoked?.call();

      case DwChannelClosedReason.notAllowed:
        // Signing out reopens the app's channels (see [_followUser]) — with
        // nobody signed in, so every `guarded` one among them is refused. That
        // is the server working, not the app misdeclaring: the refusal is the
        // expected answer to a question asked on the way out, and reporting it
        // put an error in front of a user whose last action was to leave.
        //
        // Dropped quietly instead. The screen that wants the channel asks for
        // it again when it is rebuilt under the next signed-in session.
        if (_signedInUserProfileId == null) {
          debugPrint(
            '[DwSocketService] "$channel" is closed to a signed-out app; '
            'dropped until the next sign-in',
          );
          return;
        }

        // Not noise, and not retried: either the channel is undeclared or this
        // user is not in its audience. Both are bugs in the app's channel
        // declarations, and both are silent until someone asks why a screen
        // stopped updating.
        reportError(
          Exception(
            'Subscription to "$channel" was refused. Declare it in '
            'DwCore.init(channelConfigurations: ...) and check that its rule '
            'admits this user.',
          ),
          StackTrace.current,
        );
    }
  }

  void _processUpdatedModels(List<DwModelWrapper> updatedModels) {
    DwRepository.updateListeningStates(
      wrappedModelUpdates: updatedModels
          .where((e) => e.modelId != null)
          .toList(),
    );
  }

  void _processUpdate(SerializableModel update) {
    if (update is DwModelWrapper) {
      _processUpdatedModels([update]);
    } else if (update is DwUpdatesTransport) {
      _processUpdatedModels(update.wrappedModelUpdates);
    }
  }

  /// Follows [channel] until told otherwise. Asking while the connection is
  /// down is fine: the channel is opened as soon as it comes back.
  Future<void> subscribeToChannel(String channel) async =>
      _channelSubscriptions.request(channel);

  Future<void> unsubscribeFromChannel(String channel) =>
      _channelSubscriptions.release(channel);

  Future<void> unsubscribeAllChannels() => _channelSubscriptions.releaseAll();
}
