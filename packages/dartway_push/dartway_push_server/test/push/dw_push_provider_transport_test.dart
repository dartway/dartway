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

DwPushDeliveryAttempt _attempt({required List<String> targets}) {
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
    targets: targets,
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
