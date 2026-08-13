import 'package:collection/collection.dart';
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
/// Two shapes, and the difference matters once an app ships more than one
/// transport. The default constructor keeps a single provider with an optional
/// fallback that is called **only** on an explicit
/// [DwPushProviderStatus.targetNotSupported] — right for one transport, and for
/// two whose tokens are told apart reliably by the primary.
///
/// [DwPushProviderTransport.routed] instead sends each target through the
/// transport that issued it, which the device reported at registration. Nothing
/// is guessed, so a token whose owner answers a foreign token with anything
/// other than "not mine" — an auth error, a 5xx, or worse, `UNREGISTERED` —
/// still reaches the right place instead of being retried into the void or
/// deleted while alive.
final class DwPushProviderTransport implements DwPushTransport {
  DwPushProviderTransport({
    required DwPushProvider this.provider,
    this.fallbackProvider,
    this.dataTransformer,
    this.maxConcurrentTargets = 4,
  }) : providers = const {},
       probeOrder = const [] {
    _validate();
  }

  /// Routes by [DwPushTarget.provider], keyed by the identifiers the app
  /// registers its transports under (see [DwPushProviders] for the built-in
  /// ones).
  ///
  /// A target whose provider is not yet known is probed in [probeOrder] —
  /// default: the order [providers] was declared in — and the transport that
  /// accepts it is reported back through
  /// [DwPushTargetResult.discoveredProvider], so a token is probed at most
  /// once. The probe treats **any** non-accepting answer as a reason to try the
  /// next transport, and calls the target invalid only when every one of them
  /// rejected the target itself: a transient failure must never cost a live
  /// token.
  DwPushProviderTransport.routed({
    required Map<String, DwPushProvider> providers,
    List<String>? probeOrder,
    this.dataTransformer,
    this.maxConcurrentTargets = 4,
  }) : provider = null,
       fallbackProvider = null,
       providers = Map.unmodifiable(providers),
       probeOrder = List.unmodifiable(
         probeOrder ?? providers.keys.toList(growable: false),
       ) {
    _validate();
    for (final identifier in this.probeOrder) {
      if (!this.providers.containsKey(identifier)) {
        throw ArgumentError.value(
          identifier,
          'probeOrder',
          'Must name a provider present in providers',
        );
      }
    }
  }

  /// The single transport of the default shape; null when [routed].
  final DwPushProvider? provider;
  final DwPushProvider? fallbackProvider;

  /// Transports by identifier; empty unless [routed].
  final Map<String, DwPushProvider> providers;

  /// Which transports a target of unknown provenance is offered to, in order.
  final List<String> probeOrder;

  final DwPushProviderDataTransformer? dataTransformer;
  final int maxConcurrentTargets;

  void _validate() {
    if (maxConcurrentTargets <= 0) {
      throw ArgumentError.value(
        maxConcurrentTargets,
        'maxConcurrentTargets',
        'Must be positive',
      );
    }
  }

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
    DwPushTarget target,
  ) async {
    var request = DwPushProviderRequest(
      target: target.token,
      payload: attempt.payload,
      idempotencyKey: attempt.idempotencyKey,
    );
    request = dataTransformer?.call(request) ?? request;

    final singleProvider = provider;
    if (singleProvider != null) {
      final primaryOutcome = await _sendSafely(
        session,
        singleProvider,
        request,
      );
      final outcome =
          primaryOutcome.status == DwPushProviderStatus.targetNotSupported &&
              fallbackProvider != null
          ? await _sendSafely(session, fallbackProvider!, request)
          : primaryOutcome;
      return _toTargetResult(request.target, outcome);
    }

    return _sendRouted(session, request, target.provider);
  }

  /// Sends through the transport that owns the target, or finds out which one
  /// does.
  Future<DwPushTargetResult> _sendRouted(
    Session session,
    DwPushProviderRequest request,
    String? knownProvider,
  ) async {
    if (knownProvider != null) {
      final routedProvider = providers[knownProvider];
      if (routedProvider == null) {
        // Deliberately terminal rather than retryable: the token names a
        // transport this deployment does not run, and waiting will not add one.
        session.log(
          'DwPush: no provider configured for "$knownProvider", dropping '
          '${dwPushTargetFingerprint(request.target)}',
          level: LogLevel.warning,
        );
        return _toTargetResult(
          request.target,
          const DwPushProviderOutcome.permanentFailure(
            errorCode: 'provider_not_configured',
          ),
        );
      }
      return _toTargetResult(
        request.target,
        await _sendSafely(session, routedProvider, request),
      );
    }

    final outcomes = <DwPushProviderOutcome>[];
    for (final identifier in probeOrder) {
      final probedProvider = providers[identifier]!;
      final outcome = await _sendSafely(session, probedProvider, request);
      if (outcome.status == DwPushProviderStatus.accepted) {
        return _toTargetResult(
          request.target,
          outcome,
          discoveredProvider: identifier,
        );
      }
      outcomes.add(outcome);
    }

    return _toTargetResult(request.target, _combine(outcomes));
  }

  /// Folds the answers of every transport that refused the target.
  ///
  /// Only a refusal *of the target itself* by all of them justifies dropping
  /// the token. Anything transient anywhere keeps it and retries — the whole
  /// point of probing is to be wrong about the transport, not about the device.
  DwPushProviderOutcome _combine(List<DwPushProviderOutcome> outcomes) {
    if (outcomes.isEmpty) {
      return const DwPushProviderOutcome.permanentFailure(
        errorCode: 'no_push_provider_configured',
      );
    }
    if (outcomes.every(_rejectsTarget)) {
      return DwPushProviderOutcome.invalidTarget(
        errorCode: outcomes.first.errorCode,
      );
    }
    final retryable = outcomes.firstWhereOrNull(
      (outcome) => outcome.status == DwPushProviderStatus.retryableFailure,
    );
    if (retryable != null) {
      return DwPushProviderOutcome.retryableFailure(
        errorCode: retryable.errorCode,
        retryAfter: retryable.retryAfter,
      );
    }
    return DwPushProviderOutcome.permanentFailure(
      errorCode: outcomes.first.errorCode,
    );
  }

  bool _rejectsTarget(DwPushProviderOutcome outcome) =>
      outcome.status == DwPushProviderStatus.invalidTarget ||
      outcome.status == DwPushProviderStatus.targetNotSupported;

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
    DwPushProviderOutcome outcome, {
    String? discoveredProvider,
  }) {
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
      discoveredProvider: discoveredProvider,
    );
  }
}
