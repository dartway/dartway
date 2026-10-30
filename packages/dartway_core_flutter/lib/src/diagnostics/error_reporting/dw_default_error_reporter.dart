import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/widgets.dart';

import '../../core/logic/dw_key_value_store.dart';
import 'dw_error_report.dart';

final class DwDefaultErrorReporter with WidgetsBindingObserver {
  DwDefaultErrorReporter({required this.client, required this.store});
  final DwAppClient client;
  final DwKeyValueStorePlugin? Function() store;
  static const _key = 'dw.error-reports';
  static const _deviceKey = 'dw.error-device';
  final List<Map<String, Object?>> _queue = [];
  Future<void> _serial = Future.value();
  String? _deviceId;
  bool _loaded = false;
  Timer? _sendTimer;
  bool _stopped = false;
  WidgetsBinding? _binding;

  Future<void> start() async {
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
        await _load();
        final stack = _truncate('${report.stackTrace}', 16 << 10);
        final frame = stack
            .split('\n')
            .map((line) => line.trim())
            .firstWhere(
              (line) =>
                  line.isNotEmpty &&
                  !line.contains('dart:') &&
                  !line.contains('package:flutter/') &&
                  !line.contains('package:dartway_') &&
                  !line.contains('<asynchronous suspension>'),
              orElse: () => '',
            )
            .replaceFirst(RegExp(r'^#\d+\s+'), '');
        final signature = '${report.error.runtimeType}|$frame';
        Map<String, Object?>? existing;
        for (final item in _queue) {
          if (item['signature'] == signature) existing = item;
        }
        if (existing != null) {
          existing['count'] = (existing['count']! as int) + 1;
        } else {
          if (_queue.length == 50) _queue.removeAt(0);
          final item = <String, Object?>{
            'deviceId': _deviceId,
            'signature': signature,
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
              for (final entry in report.context.entries.entries.take(25))
                _truncate(entry.key, 64): _truncate(entry.value, 512),
            },
            'count': 1,
          };
          _fitBody(item);
          _queue.add(item);
        }
        await _save();
        if (!_stopped) {
          _sendTimer?.cancel();
          _sendTimer = Timer(const Duration(milliseconds: 500), serverReached);
        }
      }),
    );
  }

  void serverReached() => unawaited(_run(_flush));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) serverReached();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final storage = store();
    _deviceId = await storage?.getString(_deviceKey);
    if (_deviceId == null) {
      final random = Random.secure();
      _deviceId = List.generate(
        24,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      await storage?.setString(_deviceKey, _deviceId!);
    }
    final encoded = await storage?.getString(_key);
    if (encoded != null) {
      try {
        _queue.addAll(
          (jsonDecode(encoded) as List).cast<Map>().map(
            (item) => item.cast<String, Object?>(),
          ),
        );
      } catch (_) {
        await storage?.remove(_key);
      }
    }
  }

  Future<void> _save() async {
    final storage = store();
    if (_queue.isEmpty) {
      await storage?.remove(_key);
    } else {
      await storage?.setString(_key, jsonEncode(_queue));
    }
  }

  Future<void> _flush() async {
    while (!_stopped && _queue.isNotEmpty) {
      try {
        // The method is intentionally public on the internal family client,
        // but the analyzer treats that re-export as internal across packages.
        // ignore: invalid_use_of_internal_member
        final reply = await client
            .postFrameworkJson(
              DwHttpContract.clientErrorPath,
              jsonEncode(_queue.first),
            )
            .timeout(const Duration(seconds: 10));
        if (reply.status == 404) {
          _stopped = true;
          _queue.clear();
          await _save();
          return;
        }
        if (reply.status == 429 || reply.status >= 500) return;
        if (reply.status < 200 || reply.status >= 300) {
          _queue.removeAt(0);
          await _save();
          continue;
        }
      } catch (_) {
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
      (utf8.encode(stack).length - encoded + limit).clamp(0, 16 << 10),
    );
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _serial.then((_) => operation());
    _serial = next.catchError((_) {});
    return next;
  }
}
