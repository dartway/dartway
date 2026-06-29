import 'package:serverpod_client/serverpod_client.dart';

import '../app/socket/service/streaming_error_classifier.dart';

// Composable builders that route connection-level failures (network blips,
// offline, slow/unreachable backend) away from alerting, reusing the single
// source of truth [isStreamingConnectionError]. Apps supply their own policy
// (toast text, alert sink) instead of duplicating the classifier.

/// Builds a `Client.onFailedCall` handler: connection-level failures go to
/// [onConnectionError] (default: silently ignored — no alert), everything else
/// to [onUnexpectedError] (the app's alert/report sink).
void Function(MethodCallContext, Object, StackTrace) dwConnectionAwareOnFailedCall({
  void Function(MethodCallContext ctx, Object error)? onConnectionError,
  required void Function(MethodCallContext ctx, Object error, StackTrace st)
  onUnexpectedError,
}) {
  return (ctx, error, st) {
    if (isStreamingConnectionError(error)) {
      onConnectionError?.call(ctx, error);
      return;
    }
    onUnexpectedError(ctx, error, st);
  };
}

/// Builds a zone / `globalErrorHandler` handler with the same routing, but
/// without a [MethodCallContext]: connection-level → [onConnectionError]
/// (default: ignored), otherwise → [onUnexpectedError].
void Function(Object, StackTrace) dwConnectionAwareErrorHandler({
  void Function(Object error)? onConnectionError,
  required void Function(Object error, StackTrace st) onUnexpectedError,
}) {
  return (error, st) {
    if (isStreamingConnectionError(error)) {
      onConnectionError?.call(error);
      return;
    }
    onUnexpectedError(error, st);
  };
}
