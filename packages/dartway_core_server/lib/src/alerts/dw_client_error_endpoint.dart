import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../context/dw_call_context.dart';
import 'dw_server_logger.dart';
import '../http/dw_http_request.dart';
import '../http/dw_http_response.dart';
import '../http/dw_peer_rate_limits.dart';
import '../routes/dw_http_route.dart';
import '../server/dw_runtime.dart';
import '../server/dw_server_settings.dart';

/// The guarded public door used by the built-in Flutter reporter.
final class DwClientErrorEndpoint {
  DwClientErrorEndpoint(this.runtime, DwServerSettings settings)
    : _peersResolver = DwPeerRateLimits(settings),
      _clientBudget = settings.alertsPerMinute;

  final DwRuntime runtime;
  final DwPeerRateLimits _peersResolver;
  final Map<String, List<DateTime>> _devices = {};
  final Map<String, List<DateTime>> _peers = {};
  final List<DateTime> _recentClients = [];
  final int _clientBudget;
  int _droppedClients = 0;

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
    if (!_charge(
          _peers,
          _peersResolver.peerKey(request.rawRequest) ?? '-',
          now,
          60,
        ) ||
        !_charge(_devices, device, now, 30)) {
      return DwHttpResponse.empty(status: 429, headers: {'retry-after': '60'});
    }
    final platform = _field(value, 'platform', 32, required: true);
    final route = _field(value, 'route', 512);
    final error = _field(value, 'error', 4096, required: true);
    final errorType = _field(value, 'errorType', 128, required: true);
    final stack = _field(value, 'stackTrace', 16 << 10) ?? '';
    final appVersion = _field(value, 'appVersion', 64);
    final features = value['featureIds'];
    final entries = value['entries'];
    final count = value['count'];
    if (platform == null ||
        (value.containsKey('route') && route == null) ||
        error == null ||
        errorType == null ||
        count is! int ||
        count < 1 ||
        count > 1000000 ||
        features is! List ||
        features.length > 50 ||
        features.any(
          (item) => item is! String || utf8.encode(item).length > 128,
        ) ||
        entries is! Map ||
        entries.length > 25 ||
        entries.entries.any(
          (item) =>
              item.key is! String ||
              item.value is! String ||
              utf8.encode(item.key as String).length > 64 ||
              utf8.encode(item.value as String).length > 512,
        )) {
      return _bad();
    }
    _recentClients.removeWhere(
      (sent) => now.difference(sent) >= const Duration(minutes: 1),
    );
    if (_recentClients.length >= _clientBudget) {
      _droppedClients++;
      runtime.log.log(
        DwLogLevel.warning,
        'client incident dropped by the $_clientBudget/minute enqueue budget '
        '($_droppedClients dropped since the last accepted incident)',
      );
      return DwHttpResponse.empty(status: 429, headers: {'retry-after': '60'});
    }
    if (_droppedClients > 0) {
      runtime.log.log(
        DwLogLevel.warning,
        'client incident enqueue resumed after $_droppedClients dropped reports',
      );
      _droppedClients = 0;
    }
    _recentClients.add(now);
    final context = <String>[
      error,
      if (appVersion != null) 'app version: $appVersion',
      if (features.isNotEmpty) 'features: ${features.join(', ')}',
      for (final item in entries.entries)
        if (item.key != 'account') '${item.key}: ${item.value}',
      if (count > 1) 'device occurrences: $count',
    ].join('\n');
    runtime.alerts.report(
      where: 'client $platform ${route ?? '-'}',
      error: context,
      stackTrace: StackTrace.fromString(stack),
      accountId: ctx.accountId,
      signature: _signature(platform, errorType, stack, ctx.accountId),
    );
    return DwHttpResponse.empty();
  }

  static String _signature(
    String platform,
    String errorType,
    String stack,
    int? accountId,
  ) {
    final normalizedType = errorType.replaceAll(
      RegExp(r'[\r\n\u0000-\u001f]'),
      ' ',
    );
    return 'client|$platform|$normalizedType|${dwFirstAppFrame(stack)}'
        '${accountId == null ? '' : '|account:$accountId'}';
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
            (!required || value.isNotEmpty) &&
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
