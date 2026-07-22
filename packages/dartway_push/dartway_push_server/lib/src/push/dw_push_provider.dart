import 'dart:collection';

import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';
import 'dw_push_provider_utils.dart';
import 'dw_push_transport.dart';

enum DwPushProviderStatus {
  accepted,
  invalidTarget,
  targetNotSupported,
  retryableFailure,
  permanentFailure,
}

/// Provider-neutral request for one target.
final class DwPushProviderRequest {
  DwPushProviderRequest({
    required String target,
    required this.payload,
    Map<String, String>? data,
    this.idempotencyKey,
  }) : target = target.trim(),
       data = UnmodifiableMapView(Map.of(data ?? payload.data)) {
    if (this.target.isEmpty) {
      throw ArgumentError.value(target, 'target', 'Must not be empty');
    }
  }

  final String target;
  final DwPushPayload payload;
  final Map<String, String> data;
  final String? idempotencyKey;

  DwPushProviderRequest copyWith({
    String? target,
    DwPushPayload? payload,
    Map<String, String>? data,
    String? idempotencyKey,
  }) => DwPushProviderRequest(
    target: target ?? this.target,
    payload: payload ?? this.payload,
    data: data ?? this.data,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
  );
}

/// Classified result of one provider call. Raw tokens and response bodies do
/// not belong in this object.
final class DwPushProviderOutcome {
  const DwPushProviderOutcome.accepted({this.errorCode})
    : status = DwPushProviderStatus.accepted,
      retryAfter = null;

  const DwPushProviderOutcome.invalidTarget({this.errorCode})
    : status = DwPushProviderStatus.invalidTarget,
      retryAfter = null;

  const DwPushProviderOutcome.targetNotSupported({this.errorCode})
    : status = DwPushProviderStatus.targetNotSupported,
      retryAfter = null;

  const DwPushProviderOutcome.retryableFailure({
    this.errorCode,
    this.retryAfter,
  }) : status = DwPushProviderStatus.retryableFailure;

  const DwPushProviderOutcome.permanentFailure({this.errorCode})
    : status = DwPushProviderStatus.permanentFailure,
      retryAfter = null;

  final DwPushProviderStatus status;
  final String? errorCode;
  final Duration? retryAfter;
}

abstract interface class DwPushProvider {
  Future<DwPushProviderOutcome> send(
    Session session,
    DwPushProviderRequest request,
  );
}

typedef DwPushProviderDataTransformer =
    DwPushProviderRequest Function(DwPushProviderRequest request);

/// Adapts per-target providers to the batch-oriented [DwPushTransport] seam.
///
/// The fallback provider is called only when the primary provider explicitly
/// reports [DwPushProviderStatus.targetNotSupported].
final class DwPushProviderTransport implements DwPushTransport {
  DwPushProviderTransport({
    required this.provider,
    this.fallbackProvider,
    this.dataTransformer,
    this.maxConcurrentTargets = 4,
  }) {
    if (maxConcurrentTargets <= 0) {
      throw ArgumentError.value(
        maxConcurrentTargets,
        'maxConcurrentTargets',
        'Must be positive',
      );
    }
  }

  final DwPushProvider provider;
  final DwPushProvider? fallbackProvider;
  final DwPushProviderDataTransformer? dataTransformer;
  final int maxConcurrentTargets;

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) async {
    final results = <DwPushTargetResult>[];
    for (
      var offset = 0;
      offset < attempt.targets.length;
      offset += maxConcurrentTargets
    ) {
      final end = (offset + maxConcurrentTargets).clamp(
        0,
        attempt.targets.length,
      );
      results.addAll(
        await Future.wait(
          attempt.targets
              .sublist(offset, end)
              .map((target) => _sendTarget(session, attempt, target)),
        ),
      );
    }
    return DwPushTransportResult(results);
  }

  Future<DwPushTargetResult> _sendTarget(
    Session session,
    DwPushDeliveryAttempt attempt,
    String target,
  ) async {
    var request = DwPushProviderRequest(
      target: target,
      payload: attempt.payload,
      idempotencyKey: attempt.idempotencyKey,
    );
    request = dataTransformer?.call(request) ?? request;

    final primaryOutcome = await _sendSafely(session, provider, request);
    final outcome =
        primaryOutcome.status == DwPushProviderStatus.targetNotSupported &&
            fallbackProvider != null
        ? await _sendSafely(session, fallbackProvider!, request)
        : primaryOutcome;
    return _toTargetResult(request.target, outcome);
  }

  Future<DwPushProviderOutcome> _sendSafely(
    Session session,
    DwPushProvider selectedProvider,
    DwPushProviderRequest request,
  ) async {
    try {
      return await selectedProvider.send(session, request);
    } catch (error, stackTrace) {
      session.log(
        'DwPush provider failed unexpectedly '
        '(${dwPushSafeExceptionCode(error)})',
        level: LogLevel.error,
        stackTrace: stackTrace,
      );
      return const DwPushProviderOutcome.retryableFailure(
        errorCode: 'provider_exception',
      );
    }
  }

  DwPushTargetResult _toTargetResult(
    String target,
    DwPushProviderOutcome outcome,
  ) {
    final status = switch (outcome.status) {
      DwPushProviderStatus.accepted => DwPushTargetStatus.sent,
      DwPushProviderStatus.invalidTarget => DwPushTargetStatus.invalid,
      // targetNotSupported is an intermediate fallback signal. If it reaches
      // the transport boundary, no configured provider can own the target and
      // retaining it would repeat the same terminal failure forever.
      DwPushProviderStatus.targetNotSupported => DwPushTargetStatus.invalid,
      DwPushProviderStatus.retryableFailure =>
        DwPushTargetStatus.retryableFailure,
      DwPushProviderStatus.permanentFailure =>
        DwPushTargetStatus.permanentFailure,
    };
    return DwPushTargetResult(
      target: target,
      status: status,
      errorCode: outcome.errorCode,
      retryAfter: outcome.retryAfter,
    );
  }
}
