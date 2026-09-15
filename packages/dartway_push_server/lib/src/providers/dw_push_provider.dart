import 'package:dartway_push_shared/dartway_push_shared.dart';

/// Sends one notification to one device token of its [transport].
///
/// The framework ships [DwFcmProvider] and [DwRuStoreProvider]; a device is
/// always sent through the provider of the transport it registered with.
/// A provider never throws for an answer of its service: it classifies it.
/// What it throws (a broken socket) the worker records as a retryable failure
/// with the error's text.
abstract interface class DwPushProvider {
  DwPushTransport get transport;

  Future<DwPushOutcome> send(DwPushRequest request);

  /// Releases the HTTP client.
  Future<void> close();
}

/// One notification for one device.
final class DwPushRequest {
  const DwPushRequest({
    required this.token,
    required this.title,
    this.body,
    this.imageUrl,
    this.data = const {},
    this.link,
    this.ttl,
  });

  final String token;
  final String title;
  final String? body;
  final String? imageUrl;

  /// The provider data map (`DwPushData.toWire`).
  final Map<String, String> data;

  /// The in-app path, also in [data]; a web push opens it.
  final String? link;

  /// How long the service may hold the message for an offline device.
  final Duration? ttl;
}

/// How a provider answered one send. Every failure carries the service's own
/// words in [reason] — its status and message — never an exception's type
/// name, so an operator reading a failed delivery knows what happened.
sealed class DwPushOutcome {
  const DwPushOutcome();

  String? get reason;
}

/// The service accepted the message for the device.
final class DwPushAccepted extends DwPushOutcome {
  const DwPushAccepted();

  @override
  String? get reason => null;
}

/// The token will never work again (uninstalled, expired): the device's
/// registration — of this transport only — is removed.
final class DwPushTokenInvalid extends DwPushOutcome {
  const DwPushTokenInvalid(this.reason);

  @override
  final String reason;
}

/// A failure that may pass: the service is unavailable or rate-limits, the
/// network failed. Retried with backoff, not sooner than [retryAfter].
final class DwPushRetryLater extends DwPushOutcome {
  const DwPushRetryLater(this.reason, {this.retryAfter});

  @override
  final String reason;
  final Duration? retryAfter;
}

/// A failure retrying will not fix — a message the service refuses, a
/// credential it does not accept. Recorded for this device; the token stays.
final class DwPushRejected extends DwPushOutcome {
  const DwPushRejected(this.reason);

  @override
  final String reason;
}
