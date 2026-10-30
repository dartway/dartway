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

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await _run(() async {
      await _load();
      await _flush();
    });
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    _sendTimer?.cancel();
    await _serial;
    _sendTimer?.cancel();
  }

  void report(DwErrorReport report) => unawaited(
    _run(() async {
      await _load();
      final stack = '${report.stackTrace}';
      final frame = stack
          .split('\n')
          .map((line) => line.trim())
          .firstWhere(
            (line) =>
                line.isNotEmpty &&
                !line.contains('dartway_core_flutter') &&
                !line.contains('dart:async') &&
                !line.contains('<asynchronous'),
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
        _queue.add({
          'deviceId': _deviceId,
          'signature': signature,
          'error': '${report.error}',
          'stackTrace': stack,
          'platform': report.context.platform,
          'appVersion': report.context.appVersion,
          'route': report.context.route,
          'featureIds': report.context.featureIds,
          'entries': report.context.entries,
          'count': 1,
        });
      }
      await _save();
      _sendTimer?.cancel();
      _sendTimer = Timer(const Duration(milliseconds: 500), serverReached);
    }),
  );

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
    while (_queue.isNotEmpty) {
      try {
        final reply = await client.httpTransport
            .post(
              DwHttpPost(
                url: client.frameworkUrl(DwHttpContract.clientErrorPath),
                headers: {
                  DwHttpContract.contentTypeHeader:
                      DwHttpContract.jsonContentType,
                  if (client.frameworkAuthorization case final authorization?)
                    DwHttpContract.authorizationHeader: authorization,
                },
                body: jsonEncode(_queue.first),
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (reply.status < 200 || reply.status >= 300) return;
      } catch (_) {
        return;
      }
      _queue.removeAt(0);
      await _save();
    }
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _serial.then((_) => operation());
    _serial = next.catchError((_) {});
    return next;
  }
}
