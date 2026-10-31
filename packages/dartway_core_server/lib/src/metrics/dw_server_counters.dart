import 'dart:collection';

import '../server/dw_server_clock.dart';

/// In-memory, minute-bucketed call counters retained for Studio.
final class DwServerCounters {
  DwServerCounters({required DwServerClock clock}) : _clock = clock;

  final DwServerClock _clock;
  final SplayTreeMap<DateTime, Map<String, _CallBucket>> _minutes =
      SplayTreeMap();

  void record(
    String endpoint,
    int status,
    Duration elapsed, {
    required bool keyAction,
  }) {
    final minute = _minute(_clock.now());
    final endpoints = _minutes.putIfAbsent(minute, () => {});
    (endpoints[endpoint] ??= _CallBucket(keyAction)).add(status, elapsed);
    _discardOld(minute);
  }

  /// Closed minutes strictly after [cursor], oldest first.
  List<Map<String, Object?>> read(DateTime? cursor) {
    final current = _minute(_clock.now());
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

  /// Constant-work comparison for a configured read token. A missing token
  /// means the endpoint is disabled, including for an empty supplied value.
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
  final List<int> _micros = [];

  void add(int status, Duration elapsed) {
    calls++;
    if (status >= 500) errors++;
    _micros.add(elapsed.inMicroseconds);
  }

  Map<String, Object> toJson() {
    _micros.sort();
    return {
      'calls': calls,
      'errors': errors,
      'keyAction': keyAction,
      'responseTimeMs': {
        'p50': _percentile(0.50) / 1000,
        'p95': _percentile(0.95) / 1000,
        'max': _micros.last / 1000,
      },
    };
  }

  int _percentile(double percentile) =>
      _micros[(calls * percentile).ceil().clamp(1, calls) - 1];
}
