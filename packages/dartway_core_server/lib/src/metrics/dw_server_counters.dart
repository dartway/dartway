import 'dart:collection';

import '../server/dw_server_clock.dart';

/// In-memory, minute-bucketed call counters retained for Studio.
final class DwServerCounters {
  DwServerCounters({required DwServerClock clock})
    : _clock = clock,
      _startedAt = _minute(clock.now());

  final DwServerClock _clock;
  final DateTime _startedAt;
  final SplayTreeMap<DateTime, Map<String, _CallBucket>> _minutes =
      SplayTreeMap();

  void record(
    String endpoint,
    int status,
    Duration elapsed, {
    required bool keyAction,
  }) {
    final minute = _minute(_clock.now());
    _closeBefore(minute);
    final endpoints = _minutes.putIfAbsent(minute, () => {});
    (endpoints[endpoint] ??= _CallBucket(keyAction)).add(status, elapsed);
    _discardOld(minute);
  }

  /// Closed minutes strictly after [cursor], oldest first.
  List<Map<String, Object?>> read(DateTime? cursor, {DateTime? now}) {
    final current = _minute(now ?? _clock.now());
    _closeBefore(current);
    _discardOld(current);
    return [
      for (final entry in _minutes.entries)
        if (entry.key.isBefore(current) &&
            (cursor == null || entry.key.isAfter(_minute(cursor))))
          {
            'minute': entry.key.toIso8601String(),
            'endpoints': {
              for (final endpoint in entry.value.entries)
                endpoint.key: endpoint.value.toJson(),
            },
          },
    ];
  }

  /// Earliest minute whose zero or non-zero count this process can vouch for.
  DateTime coveredSince(DateTime now) {
    final retentionStart = _minute(now).subtract(const Duration(hours: 1));
    return _startedAt.isAfter(retentionStart) ? _startedAt : retentionStart;
  }

  static bool acceptsToken(String? expected, String? sent) {
    if (expected == null || sent == null || sent.length != expected.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ sent.codeUnitAt(i);
    }
    return difference == 0;
  }

  void _closeBefore(DateTime current) {
    for (final entry in _minutes.entries) {
      if (!entry.key.isBefore(current)) break;
      for (final bucket in entry.value.values) {
        bucket.close();
      }
    }
  }

  void _discardOld(DateTime current) {
    final oldest = current.subtract(const Duration(hours: 1));
    while (_minutes.isNotEmpty && _minutes.firstKey()!.isBefore(oldest)) {
      _minutes.remove(_minutes.firstKey());
    }
  }

  static DateTime _minute(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }
}

final class _CallBucket {
  _CallBucket(this.keyAction);

  final bool keyAction;
  int calls = 0;
  int errors = 0;
  List<int>? _micros = [];
  Map<String, num>? _responseTimeMs;

  void add(int status, Duration elapsed) {
    calls++;
    if (status >= 500) errors++;
    _micros!.add(elapsed.inMicroseconds);
  }

  void close() {
    final samples = _micros;
    if (samples == null) return;
    samples.sort();
    int percentile(double value) =>
        samples[(calls * value).ceil().clamp(1, calls) - 1];
    _responseTimeMs = {
      'p50': percentile(0.50) / 1000,
      'p95': percentile(0.95) / 1000,
      'max': samples.last / 1000,
    };
    _micros = null;
  }

  Map<String, Object> toJson() {
    close();
    return {
      'calls': calls,
      'errors': errors,
      'keyAction': keyAction,
      'responseTimeMs': _responseTimeMs!,
    };
  }
}
