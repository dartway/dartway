import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  group('DwPushProviderTransport', () {
    test(
      'falls back only for targets not supported by the primary provider',
      () async {
        final primary = _RecordingProvider(
          outcomesByTarget: {
            'fcm-token': const DwPushProviderOutcome.accepted(),
            'ru-token': const DwPushProviderOutcome.targetNotSupported(),
            'bad-token': const DwPushProviderOutcome.invalidTarget(),
            'retry-token': const DwPushProviderOutcome.retryableFailure(
              retryAfter: Duration(minutes: 2),
            ),
          },
        );
        final fallback = _RecordingProvider(
          outcomesByTarget: {
            'ru-token': const DwPushProviderOutcome.accepted(),
          },
        );
        final transport = DwPushProviderTransport(
          provider: primary,
          fallbackProvider: fallback,
        );

        final result = await transport.send(
          _FakeSession(),
          _attempt(
            targets: ['fcm-token', 'ru-token', 'bad-token', 'retry-token'],
          ),
        );

        expect(primary.requests.map((request) => request.target), [
          'fcm-token',
          'ru-token',
          'bad-token',
          'retry-token',
        ]);
        expect(fallback.requests.map((request) => request.target), [
          'ru-token',
        ]);
        expect(
          result.results.map((item) => (item.target, item.status)).toList(),
          [
            ('fcm-token', DwPushTargetStatus.sent),
            ('ru-token', DwPushTargetStatus.sent),
            ('bad-token', DwPushTargetStatus.invalid),
            ('retry-token', DwPushTargetStatus.retryableFailure),
          ],
        );
        expect(result.results.last.retryAfter, const Duration(minutes: 2));
      },
    );

    test(
      'invalidates an unsupported target when the provider chain ends',
      () async {
        final transport = DwPushProviderTransport(
          provider: _RecordingProvider(
            outcomesByTarget: {
              'foreign-token': const DwPushProviderOutcome.targetNotSupported(),
            },
          ),
        );

        final result = await transport.send(
          _FakeSession(),
          _attempt(targets: ['foreign-token']),
        );

        expect(result.results.single.status, DwPushTargetStatus.invalid);
      },
    );

    test(
      'treats provider exceptions as retryable failures for every target',
      () async {
        const sensitiveValue = 'raw-device-token-must-not-be-logged';
        final session = _RecordingSession();
        final transport = DwPushProviderTransport(
          provider: _ThrowingProvider(Exception(sensitiveValue)),
        );

        final result = await transport.send(
          session,
          _attempt(targets: ['token-a', 'token-b']),
        );

        expect(result.results.map((item) => item.target), [
          'token-a',
          'token-b',
        ]);
        expect(
          result.results.map((item) => item.status),
          everyElement(DwPushTargetStatus.retryableFailure),
        );
        expect(session.logMessages.join(), isNot(contains(sensitiveValue)));
        expect(session.loggedExceptions, isNot(contains(isNotNull)));
      },
    );

    test(
      'applies the data transformer before delegating to the provider',
      () async {
        final provider = _RecordingProvider(
          outcomesByTarget: {'token-a': const DwPushProviderOutcome.accepted()},
        );
        final transport = DwPushProviderTransport(
          provider: provider,
          dataTransformer: (request) => request.copyWith(
            data: {
              ...request.data,
              'messageId': request.payload.messageId.toString(),
            },
          ),
        );

        await transport.send(_FakeSession(), _attempt(targets: ['token-a']));

        expect(provider.requests.single.data, {
          'course_id': '42',
          'messageId': '99',
        });
      },
    );

    test(
      'bounds target concurrency to four by default and keeps order',
      () async {
        final provider = _PeakConcurrencyProvider();
        final targets = List.generate(9, (index) => 'token-$index');
        final transport = DwPushProviderTransport(provider: provider);

        final result = await transport.send(
          _FakeSession(),
          _attempt(targets: targets),
        );

        expect(provider.peakInFlight, lessThanOrEqualTo(4));
        expect(result.results.map((item) => item.target), targets);
      },
    );

    test('honors configured target concurrency', () async {
      final provider = _PeakConcurrencyProvider();
      final targets = List.generate(5, (index) => 'token-$index');
      final transport = DwPushProviderTransport(
        provider: provider,
        maxConcurrentTargets: 2,
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(targets: targets),
      );

      expect(provider.peakInFlight, 2);
      expect(result.results.map((item) => item.target), targets);
    });

    test('rejects non-positive target concurrency', () {
      expect(
        () => DwPushProviderTransport(
          provider: _PeakConcurrencyProvider(),
          maxConcurrentTargets: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('DwPushProviderTransport.routed', () {
    test('sends each target through the provider that issued it', () async {
      final fcm = _RecordingProvider(
        outcomesByTarget: {'fcm-token': const DwPushProviderOutcome.accepted()},
      );
      final ruStore = _RecordingProvider(
        outcomesByTarget: {'ru-token': const DwPushProviderOutcome.accepted()},
      );
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: fcm,
          DwPushProviders.ruStore: ruStore,
        },
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(
          targets: ['fcm-token', 'ru-token'],
          providersByToken: {
            'fcm-token': DwPushProviders.fcm,
            'ru-token': DwPushProviders.ruStore,
          },
        ),
      );

      expect(fcm.requests.map((request) => request.target), ['fcm-token']);
      expect(ruStore.requests.map((request) => request.target), ['ru-token']);
      expect(
        result.results.map((item) => item.status),
        everyElement(DwPushTargetStatus.sent),
      );
      expect(result.discoveredProviders, isEmpty);
    });

    test('probes a target of unknown provenance and reports what it '
        'found', () async {
      final fcm = _RecordingProvider(
        outcomesByTarget: {
          'ru-token': const DwPushProviderOutcome.targetNotSupported(),
        },
      );
      final ruStore = _RecordingProvider(
        outcomesByTarget: {'ru-token': const DwPushProviderOutcome.accepted()},
      );
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: fcm,
          DwPushProviders.ruStore: ruStore,
        },
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(targets: ['ru-token']),
      );

      expect(fcm.requests, hasLength(1));
      expect(ruStore.requests, hasLength(1));
      expect(result.results.single.status, DwPushTargetStatus.sent);
      expect(result.discoveredProviders, {'ru-token': DwPushProviders.ruStore});
    });

    test('keeps a live token when one provider fails transiently', () async {
      // The regression this whole mechanism exists for: FCM answering a
      // foreign token with UNREGISTERED used to delete a working RuStore
      // token. Only a refusal of the target by *every* provider may do that.
      final fcm = _RecordingProvider(
        outcomesByTarget: {
          'ru-token': const DwPushProviderOutcome.invalidTarget(
            errorCode: 'fcm_unregistered',
          ),
        },
      );
      final ruStore = _RecordingProvider(
        outcomesByTarget: {
          'ru-token': const DwPushProviderOutcome.retryableFailure(
            errorCode: 'rustore_503',
            retryAfter: Duration(minutes: 3),
          ),
        },
      );
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: fcm,
          DwPushProviders.ruStore: ruStore,
        },
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(targets: ['ru-token']),
      );

      expect(result.results.single.status, DwPushTargetStatus.retryableFailure);
      expect(result.results.single.retryAfter, const Duration(minutes: 3));
      expect(result.invalidTargets, isEmpty);
    });

    test('invalidates a target every provider refuses', () async {
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: _RecordingProvider(
            outcomesByTarget: {
              'dead-token': const DwPushProviderOutcome.invalidTarget(),
            },
          ),
          DwPushProviders.ruStore: _RecordingProvider(
            outcomesByTarget: {
              'dead-token': const DwPushProviderOutcome.targetNotSupported(),
            },
          ),
        },
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(targets: ['dead-token']),
      );

      expect(result.results.single.status, DwPushTargetStatus.invalid);
    });

    test('fails a target whose provider this deployment does not run', () async {
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: _RecordingProvider(outcomesByTarget: const {}),
        },
      );

      final result = await transport.send(
        _RecordingSession(),
        _attempt(
          targets: ['ru-token'],
          providersByToken: {'ru-token': DwPushProviders.ruStore},
        ),
      );

      // Terminal, but not "invalid": the token is fine, the deployment is not,
      // and deleting it would cost the device its registration for good.
      expect(result.results.single.status, DwPushTargetStatus.permanentFailure);
      expect(result.results.single.errorCode, 'provider_not_configured');
      expect(result.invalidTargets, isEmpty);
    });

    test('probes in the configured order', () async {
      final fcm = _RecordingProvider(
        outcomesByTarget: {'token': const DwPushProviderOutcome.accepted()},
      );
      final ruStore = _RecordingProvider(
        outcomesByTarget: {'token': const DwPushProviderOutcome.accepted()},
      );
      final transport = DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: fcm,
          DwPushProviders.ruStore: ruStore,
        },
        probeOrder: [DwPushProviders.ruStore, DwPushProviders.fcm],
      );

      final result = await transport.send(
        _FakeSession(),
        _attempt(targets: ['token']),
      );

      expect(ruStore.requests, hasLength(1));
      expect(fcm.requests, isEmpty);
      expect(result.discoveredProviders, {'token': DwPushProviders.ruStore});
    });

    test('rejects a probe order naming an unconfigured provider', () {
      expect(
        () => DwPushProviderTransport.routed(
          providers: {
            DwPushProviders.fcm: _RecordingProvider(outcomesByTarget: const {}),
          },
          probeOrder: [DwPushProviders.ruStore],
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _RecordingProvider implements DwPushProvider {
  _RecordingProvider({required this.outcomesByTarget});

  final Map<String, DwPushProviderOutcome> outcomesByTarget;
  final List<DwPushProviderRequest> requests = [];

  @override
  Future<DwPushProviderOutcome> send(
    Session session,
    DwPushProviderRequest request,
  ) async {
    requests.add(request);
    return outcomesByTarget[request.target] ??
        const DwPushProviderOutcome.permanentFailure();
  }
}

final class _ThrowingProvider implements DwPushProvider {
  _ThrowingProvider(this.error);

  final Object error;

  @override
  Future<DwPushProviderOutcome> send(
    Session session,
    DwPushProviderRequest request,
  ) {
    throw error;
  }
}

final class _PeakConcurrencyProvider implements DwPushProvider {
  int inFlight = 0;
  int peakInFlight = 0;

  @override
  Future<DwPushProviderOutcome> send(
    Session session,
    DwPushProviderRequest request,
  ) async {
    inFlight++;
    if (inFlight > peakInFlight) peakInFlight = inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    inFlight--;
    return const DwPushProviderOutcome.accepted();
  }
}

DwPushDeliveryAttempt _attempt({
  required List<String> targets,
  Map<String, String> providersByToken = const {},
}) {
  return DwPushDeliveryAttempt(
    deliveryId: 17,
    recipientId: 5,
    attemptNumber: 2,
    payload: DwPushPayload(
      messageId: 99,
      category: 'news',
      title: 'Course unlocked',
      body: 'Open the app to continue',
      imageUrl: 'https://cdn.example.com/banner.png',
      data: {'course_id': '42'},
      expiresAt: DateTime.utc(2026, 7, 21, 12),
    ),
    targets: [
      for (final token in targets)
        DwPushTarget(token: token, provider: providersByToken[token]),
    ],
  );
}

final class _FakeSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final class _RecordingSession implements Session {
  final List<String> logMessages = [];
  final List<Object?> loggedExceptions = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #log) {
      logMessages.add(invocation.positionalArguments.first.toString());
      loggedExceptions.add(invocation.namedArguments[#exception]);
    }
    return null;
  }
}
