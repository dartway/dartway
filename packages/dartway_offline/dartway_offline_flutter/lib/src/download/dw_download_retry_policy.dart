enum DwDownloadFailureKind {
  connection,
  timeout,
  dns,
  tls,
  connectionReset,
  unauthorized,
  forbidden,
  checksumMismatch,
  invalidRedirect,
  invalidSchema,
  cancelled,
  scopePurged,
}

enum DwDownloadWaitReason { network, consent, disk, explicitPause }

final class DwDownloadRetryDecision {
  const DwDownloadRetryDecision._({required this.isTerminal, this.retryDelay});

  const DwDownloadRetryDecision.retry(Duration retryDelay)
    : this._(isTerminal: false, retryDelay: retryDelay);

  const DwDownloadRetryDecision.terminal() : this._(isTerminal: true);

  final bool isTerminal;
  final Duration? retryDelay;
}

final class DwDownloadRetryPolicy {
  const DwDownloadRetryPolicy._();

  static const List<Duration> _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 300),
  ];

  static DwDownloadRetryDecision evaluate({
    required DwDownloadFailureKind failureKind,
    required int completedRetries,
  }) {
    if (completedRetries < 0) {
      throw ArgumentError.value(
        completedRetries,
        'completedRetries',
        'must not be negative.',
      );
    }
    if (!_isTransient(failureKind) || completedRetries >= _retryDelays.length) {
      return const DwDownloadRetryDecision.terminal();
    }
    return DwDownloadRetryDecision.retry(_retryDelays[completedRetries]);
  }

  static int completedRetriesAfterWait({
    required int completedRetries,
    required DwDownloadWaitReason waitReason,
  }) {
    if (completedRetries < 0) {
      throw ArgumentError.value(
        completedRetries,
        'completedRetries',
        'must not be negative.',
      );
    }
    return completedRetries;
  }

  static bool _isTransient(DwDownloadFailureKind failureKind) {
    return switch (failureKind) {
      DwDownloadFailureKind.connection ||
      DwDownloadFailureKind.timeout ||
      DwDownloadFailureKind.dns ||
      DwDownloadFailureKind.tls ||
      DwDownloadFailureKind.connectionReset => true,
      DwDownloadFailureKind.unauthorized ||
      DwDownloadFailureKind.forbidden ||
      DwDownloadFailureKind.checksumMismatch ||
      DwDownloadFailureKind.invalidRedirect ||
      DwDownloadFailureKind.invalidSchema ||
      DwDownloadFailureKind.cancelled ||
      DwDownloadFailureKind.scopePurged => false,
    };
  }
}
