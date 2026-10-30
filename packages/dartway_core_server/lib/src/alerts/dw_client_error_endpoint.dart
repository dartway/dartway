import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../context/dw_call_context.dart';
import '../http/dw_http_request.dart';
import '../http/dw_http_response.dart';
import '../routes/dw_http_route.dart';
import '../server/dw_runtime.dart';

/// The guarded public door used by the built-in Flutter reporter.
final class DwClientErrorEndpoint {
  DwClientErrorEndpoint(this.runtime);

  final DwRuntime runtime;
  final Map<String, List<DateTime>> _devices = {};
  final Map<String, List<DateTime>> _peers = {};

  DwHttpRoute get route => DwHttpRoute.post(
    DwHttpContract.clientErrorPath,
    _answer,
    auth: DwRouteAuth.optional,
  );

  Future<DwHttpResponse> _answer(
    DwCallContext ctx,
    DwHttpRequest request,
  ) async {
    final value = await request.json(maxBytes: 32 << 10);
    if (value is! Map<String, Object?>) return _bad();
    final device = _field(value, 'deviceId', 128, required: true);
    if (device == null) return _bad();
    final now = DateTime.now().toUtc();
    if (!_charge(_peers, request.peerKey, now, 60) ||
        !_charge(_devices, device, now, 30)) {
      return DwHttpResponse.empty(status: 429, headers: {'retry-after': '60'});
    }
    final platform = _field(value, 'platform', 32, required: true);
    final route = _field(value, 'route', 512) ?? '-';
    final error = _field(value, 'error', 4096, required: true);
    final stack = _field(value, 'stackTrace', 16 << 10, required: true);
    final signature = _field(value, 'signature', 1024, required: true);
    final appVersion = _field(value, 'appVersion', 64);
    final features = value['featureIds'];
    final entries = value['entries'];
    final count = value['count'];
    if (platform == null ||
        error == null ||
        stack == null ||
        signature == null ||
        count is! int ||
        count < 1 ||
        count > 1000000 ||
        features is! List ||
        features.length > 50 ||
        features.any((item) => item is! String || item.length > 128) ||
        entries is! Map ||
        entries.length > 25 ||
        entries.entries.any(
          (item) =>
              item.key is! String ||
              item.value is! String ||
              (item.key as String).length > 64 ||
              (item.value as String).length > 512,
        )) {
      return _bad();
    }
    final context = <String>[
      error,
      if (appVersion != null) 'app version: $appVersion',
      if (features.isNotEmpty) 'features: ${features.join(', ')}',
      for (final item in entries.entries) '${item.key}: ${item.value}',
      if (count > 1) 'device occurrences: $count',
    ].join('\n');
    runtime.alerts.report(
      where: 'client $platform $route',
      error: context,
      stackTrace: StackTrace.fromString(stack),
      accountId: ctx.accountId,
      signature: signature,
    );
    return DwHttpResponse.empty();
  }

  static String? _field(
    Map<String, Object?> json,
    String name,
    int max, {
    bool required = false,
  }) {
    final value = json[name];
    if (value == null && !required) return null;
    return value is String &&
            value.isNotEmpty &&
            utf8.encode(value).length <= max
        ? value
        : null;
  }

  static bool _charge(
    Map<String, List<DateTime>> buckets,
    String key,
    DateTime now,
    int limit,
  ) {
    if (buckets.length > 10000) {
      buckets.removeWhere(
        (_, times) =>
            times.isEmpty || now.difference(times.last).inMinutes >= 1,
      );
    }
    final times = buckets.putIfAbsent(key, () => []);
    times.removeWhere((at) => now.difference(at).inMinutes >= 1);
    if (times.length >= limit) return false;
    times.add(now);
    return true;
  }

  static DwHttpResponse _bad() =>
      DwHttpResponse.text('malformed client error report', status: 400);
}
