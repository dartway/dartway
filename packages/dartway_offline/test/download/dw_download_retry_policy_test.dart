import 'package:dartway_offline/src/download/dw_download_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDownloadRetryPolicy', () {
    test('connection failures use the exact six-delay schedule', () {
      final observedDelays = <Duration?>[
        for (
          var completedRetries = 0;
          completedRetries <= 6;
          completedRetries++
        )
          DwDownloadRetryPolicy.evaluate(
            failureKind: DwDownloadFailureKind.connection,
            completedRetries: completedRetries,
          ).retryDelay,
      ];

      expect(observedDelays, const [
        Duration(seconds: 5),
        Duration(seconds: 15),
        Duration(seconds: 30),
        Duration(seconds: 60),
        Duration(seconds: 120),
        Duration(seconds: 300),
        null,
      ]);
    });

    test('terminal failures never receive a retry', () {
      for (final failureKind in [
        DwDownloadFailureKind.unauthorized,
        DwDownloadFailureKind.forbidden,
        DwDownloadFailureKind.checksumMismatch,
        DwDownloadFailureKind.invalidRedirect,
        DwDownloadFailureKind.invalidSchema,
        DwDownloadFailureKind.cancelled,
        DwDownloadFailureKind.scopePurged,
      ]) {
        final decision = DwDownloadRetryPolicy.evaluate(
          failureKind: failureKind,
          completedRetries: 0,
        );

        expect(decision.isTerminal, isTrue, reason: failureKind.name);
        expect(decision.retryDelay, isNull, reason: failureKind.name);
      }
    });

    test(
      'network consent disk and pause waits do not consume retry budget',
      () {
        for (final waitReason in DwDownloadWaitReason.values) {
          expect(
            DwDownloadRetryPolicy.completedRetriesAfterWait(
              completedRetries: 4,
              waitReason: waitReason,
            ),
            4,
            reason: waitReason.name,
          );
        }
      },
    );

    test('negative retry counts fail fast', () {
      expect(
        () => DwDownloadRetryPolicy.evaluate(
          failureKind: DwDownloadFailureKind.connection,
          completedRetries: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
