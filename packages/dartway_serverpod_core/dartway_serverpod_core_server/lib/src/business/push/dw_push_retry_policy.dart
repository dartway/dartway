import 'dart:math';

/// Exponential backoff policy used for retryable push delivery failures.
final class DwPushRetryPolicy {
  DwPushRetryPolicy({
    this.maxAttempts = 6,
    this.initialDelay = const Duration(seconds: 10),
    this.maximumDelay = const Duration(hours: 1),
    this.jitterFactor = 0.2,
    Random? random,
  }) : _random = random ?? Random.secure() {
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be positive');
    }
    if (initialDelay <= Duration.zero) {
      throw ArgumentError.value(
        initialDelay,
        'initialDelay',
        'Must be positive',
      );
    }
    if (maximumDelay < initialDelay) {
      throw ArgumentError.value(
        maximumDelay,
        'maximumDelay',
        'Must not be shorter than initialDelay',
      );
    }
    if (jitterFactor < 0 || jitterFactor > 1) {
      throw ArgumentError.value(
        jitterFactor,
        'jitterFactor',
        'Must be between 0 and 1',
      );
    }
  }

  /// Total number of delivery attempts, including the first one.
  final int maxAttempts;

  /// Delay after the first failed attempt.
  final Duration initialDelay;

  /// Upper bound for an exponentially growing delay.
  final Duration maximumDelay;

  /// Random variation applied symmetrically to a delay.
  final double jitterFactor;

  final Random _random;

  /// Returns the delay after [completedAttempts], or `null` when exhausted.
  Duration? delayAfterFailure(int completedAttempts) {
    if (completedAttempts < 1) {
      throw ArgumentError.value(
        completedAttempts,
        'completedAttempts',
        'Must be positive',
      );
    }
    if (completedAttempts >= maxAttempts) return null;

    final exponentialMicros =
        initialDelay.inMicroseconds * pow(2, completedAttempts - 1);
    final cappedMicros = min(
      exponentialMicros.round(),
      maximumDelay.inMicroseconds,
    );
    if (jitterFactor == 0) return Duration(microseconds: cappedMicros);

    final multiplier =
        (1 - jitterFactor) + (_random.nextDouble() * jitterFactor * 2);
    final jitteredMicros = (cappedMicros * multiplier).round().clamp(
      1,
      maximumDelay.inMicroseconds,
    );
    return Duration(microseconds: jitteredMicros);
  }
}
