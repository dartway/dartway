import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/widgets.dart';

import '../../core/logic/dw_key_value_store.dart';
import 'dw_error_report.dart';

final class DwDefaultErrorReporter with WidgetsBindingObserver {
  DwDefaultErrorReporter({
    required this.client,
    required this.store,
    this.repeatWindow = const Duration(minutes: 1),
  });
  final DwAppClient client;
  final DwKeyValueStorePlugin? Function() store;
  final Duration repeatWindow;
  static const _key = 'dw.error-reports';
  static const _deviceKey = 'dw.error-device';
  final List<Map<String, Object?>> _queue = [];
  Future<void> _serial = Future.value();
  String? _deviceId;
  bool _loaded = false;
  Timer? _sendTimer;
  Timer? _retryTimer;
  final Map<String, ({DateTime until, Map<String, Object?> item})> _recent = {};
  bool _stopped = false;
  bool _deliveryStopped = false;
  WidgetsBinding? _binding;

  Future<void> start() async {
    _deliveryStopped = false;
    _binding = WidgetsFlutterBinding.ensureInitialized()..addObserver(this);
    await _run(() async {
      await _load();
      await _flush();
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _binding?.removeObserver(this);
    _binding = null;
    _sendTimer?.cancel();
    _retryTimer?.cancel();
    // Let queued persistence finish, but never make core teardown wait for an
    // in-flight network transport owned by a server that is already gone.
    await _serial.timeout(const Duration(milliseconds: 100), onTimeout: () {});
  }

  void report(DwErrorReport report) {
    if (_stopped) return;
    unawaited(
      _run(() async {
        if (report.error is DwRefusalException ||
            report.error is DwNotAuthenticatedException) {
          return;
        }
        final stack = _truncate('${report.stackTrace}', 16 << 10);
        final errorType = '${report.error.runtimeType}';
        final signature = '$errorType|${dwFirstAppFrame(stack)}';
        final now = DateTime.now().toUtc();
        _recent.removeWhere((_, value) => !now.isBefore(value.until));
        Map<String, Object?>? existing;
        for (final item in _queue) {
          if ('${item['errorType']}|${dwFirstAppFrame(item['stackTrace'] as String? ?? '')}' ==
              signature) {
            existing = item;
          }
        }
        final recent = _recent[signature];
        if (existing == null && recent != null) {
          existing = Map<String, Object?>.of(recent.item)
            ..['count'] = 0
            ..['_sendAfter'] = recent.until.toIso8601String();
          _queue.add(existing);
        }
        if (existing != null) {
          existing['count'] = (existing['count']! as int) + 1;
        } else {
          while (_queue.length >= 50) {
            _queue.removeAt(0);
          }
          final item = <String, Object?>{
            if (_deviceId != null) 'deviceId': _deviceId,
            'errorType': errorType,
            'error': _truncate('${report.error}', 4096),
            'stackTrace': stack,
            'platform': _truncate(report.context.platform, 32),
            'appVersion': _nullableTruncate(report.context.appVersion, 64),
            'route': _nullableTruncate(report.context.route, 512),
            'featureIds': report.context.featureIds
                .take(50)
                .map((value) => _truncate(value, 128))
                .toList(),
            'entries': {
              for (final entry
                  in report.context.entries.entries
                      .where((entry) => entry.key != 'account')
                      .take(25))
                _truncate(entry.key, 64): _truncate(entry.value, 512),
            },
            'count': 1,
          };
          _fitBody(item);
          _queue.add(item);
          _recent[signature] = (until: now.add(repeatWindow), item: item);
        }
        if (_loaded) await _save();
        if (_loaded && !_stopped && !_deliveryStopped) {
          _sendTimer?.cancel();
          _schedule(const Duration(milliseconds: 500));
        }
      }),
    );
  }

  void serverReached() {
    unawaited(_run(_flush));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) serverReached();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final storage = store();
    var deviceId = await storage?.getString(_deviceKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId = List.generate(
        24,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      await storage?.setString(_deviceKey, deviceId);
    }
    final encoded = await storage?.getString(_key);
    final persisted = <Map<String, Object?>>[];
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final item = <String, Object?>{};
            for (final entry in raw.entries) {
              if (entry.key is String) item[entry.key as String] = entry.value;
            }
            if (item['errorType'] is String && item['count'] is int) {
              persisted.add(item);
            }
          }
        }
      } catch (error) {
        debugPrint('DartWay skipped malformed persisted error reports: $error');
        await storage?.remove(_key);
      }
    }
    _deviceId = deviceId;
    for (final item in _queue) {
      item['deviceId'] = deviceId;
    }
    _queue.insertAll(0, persisted);
    while (_queue.length > 50) {
      _queue.removeAt(0);
    }
    _loaded = true;
    await _save();
  }

  Future<void> _save() async {
    if (!_loaded) return;
    final storage = store();
    if (_queue.isEmpty) {
      await storage?.remove(_key);
    } else {
      await storage?.setString(_key, jsonEncode(_queue));
    }
  }

  Future<void> _flush() async {
    while (!_stopped && !_deliveryStopped && _queue.isNotEmpty) {
      final sendAfter = DateTime.tryParse(
        '${_queue.first['_sendAfter'] ?? ''}',
      );
      if (sendAfter != null && DateTime.now().toUtc().isBefore(sendAfter)) {
        _schedule(sendAfter.difference(DateTime.now().toUtc()));
        return;
      }
      try {
        // dartway_core_flutter and dartway_client are one framework family;
        // application code must not use this bearer-carrying side channel.
        var reply = await client
            // ignore: invalid_use_of_internal_member
            .postFrameworkJson(
              DwHttpContract.clientErrorPath,
              jsonEncode(_wireItem(_queue.first)),
            )
            .timeout(const Duration(seconds: 10));
        if (reply.status == 401) {
          reply = await client
              // ignore: invalid_use_of_internal_member
              .postFrameworkJson(
                DwHttpContract.clientErrorPath,
                jsonEncode(_wireItem(_queue.first)),
                authorize: false,
              )
              .timeout(const Duration(seconds: 10));
        }
        if (reply.status == 404) {
          _scheduleRetry(const Duration(minutes: 1));
          return;
        }
        if (reply.status == 429 || reply.status >= 500) {
          _scheduleRetry(const Duration(seconds: 30));
          return;
        }
        if (reply.status < 200 || reply.status >= 300) {
          debugPrint('DartWay error report dropped: HTTP ${reply.status}');
          _queue.removeAt(0);
          await _save();
          continue;
        }
      } catch (error) {
        debugPrint('DartWay error report delivery failed: $error');
        _scheduleRetry(const Duration(seconds: 10));
        return;
      }
      _queue.removeAt(0);
      await _save();
    }
  }

  static String? _nullableTruncate(String? value, int bytes) =>
      value == null ? null : _truncate(value, bytes);

  static String _truncate(String value, int bytes) {
    if (utf8.encode(value).length <= bytes) return value;
    final out = StringBuffer();
    var used = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (used + size > bytes) break;
      out.write(character);
      used += size;
    }
    return out.toString();
  }

  static void _fitBody(Map<String, Object?> item) {
    const limit = 32 << 10;
    var encoded = utf8.encode(jsonEncode(item)).length;
    if (encoded <= limit) return;
    final stack = item['stackTrace']! as String;
    item['stackTrace'] = _truncate(
      stack,
      (utf8.encode(stack).length - encoded + limit).clamp(1, 16 << 10),
    );
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _serial.then((_) async {
      try {
        await operation();
      } catch (error, stack) {
        debugPrint('DartWay error reporter failed: $error\n$stack');
      }
    });
    _serial = next;
    return next;
  }

  void _schedule(Duration delay) {
    _sendTimer?.cancel();
    _sendTimer = Timer(delay, serverReached);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, serverReached);
  }

  static Map<String, Object?> _wireItem(Map<String, Object?> item) => {
    for (final entry in item.entries)
      if (!entry.key.startsWith('_')) entry.key: entry.value,
  };
}
