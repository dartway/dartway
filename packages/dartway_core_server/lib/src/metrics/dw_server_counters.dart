import 'dart:collection';
import 'dart:math';

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
  DateTime? _openMinute;

  void record(String endpoint, int status, Duration elapsed) {
    final minute = _minute(_clock.now());
    _closeOpenBefore(minute);
    final endpoints = _minutes.putIfAbsent(minute, () => {});
    (endpoints[endpoint] ??= _CallBucket()).add(status, elapsed);
    _openMinute = minute;
    _discardOld(minute);
  }

  /// Closed minutes strictly after [cursor], oldest first.
  List<Map<String, Object?>> read(DateTime? cursor, {DateTime? now}) {
    final current = _minute(now ?? _clock.now());
    _closeOpenBefore(current);
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
    final firstWholeMinute = _startedAt.add(const Duration(minutes: 1));
    return firstWholeMinute.isAfter(retentionStart)
        ? firstWholeMinute
        : retentionStart;
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

  void _closeOpenBefore(DateTime current) {
    final open = _openMinute;
    if (open == null || !open.isBefore(current)) return;
    for (final bucket in _minutes[open]?.values ?? const <_CallBucket>[]) {
      bucket.close();
    }
    _openMinute = null;
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
  static const _sampleLimit = 1024;

  int calls = 0;
  int errors = 0;
  List<int>? _micros = [];
  final Random _random = Random();
  int _maxMicros = 0;
  Map<String, num>? _responseTimeMs;

  void add(int status, Duration elapsed) {
    calls++;
    if (status >= 500) errors++;
    final micros = elapsed.inMicroseconds;
    if (micros > _maxMicros) {
      _maxMicros = micros;
      _responseTimeMs?['max'] = micros / 1000;
    }
    final samples = _micros;
    // A rewound clock can send a call to a bucket whose sample is finalized.
    if (samples == null) return;
    if (samples.length < _sampleLimit) {
      samples.add(micros);
    } else {
      final candidate = _random.nextInt(calls);
      if (candidate < _sampleLimit) samples[candidate] = micros;
    }
  }

  void close() {
    final samples = _micros;
    if (samples == null) return;
    samples.sort();
    int percentile(double value) =>
        samples[(samples.length * value).ceil().clamp(1, samples.length) - 1];
    _responseTimeMs = {
      'p50': percentile(0.50) / 1000,
      'p95': percentile(0.95) / 1000,
      'max': _maxMicros / 1000,
    };
    _micros = null;
  }

  Map<String, Object> toJson() {
    close();
    return {
      'calls': calls,
      'errors': errors,
      'responseTimeMs': _responseTimeMs!,
    };
  }
}
