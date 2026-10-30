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
    final now = DateTime.now().toUtc();
    if (!_charge(
      _peers,
      _peersResolver.peerKey(request.rawRequest) ?? '-',
      now,
      60,
    )) {
      return DwHttpResponse.empty(status: 429, headers: {'retry-after': '60'});
    }
    final value = await request.json(
      maxBytes: DwClientErrorReport.maxBodyBytes,
    );
    final report = DwClientErrorReport.fromJson(value);
    if (report == null) return _bad();
    if (!_charge(_devices, report.deviceId, now, 30)) {
      return DwHttpResponse.empty(status: 429, headers: {'retry-after': '60'});
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
      report.error,
      if (report.appVersion != null) 'app version: ${report.appVersion}',
      if (report.featureIds.isNotEmpty)
        'features: ${report.featureIds.join(', ')}',
      for (final item in report.entries.entries)
        if (item.key != 'account') '${item.key}: ${item.value}',
      if (report.count > 1) 'device occurrences: ${report.count}',
    ].join('\n');
    final platform = dwNormalizeClientErrorLabel(report.platform);
    final route = report.route == null
        ? null
        : dwNormalizeClientErrorLabel(report.route!);
    runtime.alerts.report(
      where: 'client $platform ${route ?? '-'}',
      error: context,
      stackTrace: StackTrace.fromString(report.stackTrace),
      accountId: ctx.accountId,
      signature: _signature(
        platform,
        report.errorType,
        report.stackTrace,
        ctx.accountId,
      ),
      occurrences: report.count,
    );
    return DwHttpResponse.empty();
  }

  static String _signature(
    String platform,
    String errorType,
    String stack,
    int? accountId,
  ) {
    final normalizedType = dwNormalizeClientErrorLabel(errorType);
    return 'client|$platform|$normalizedType|${dwFirstAppFrame(stack)}'
        '|${accountId == null ? 'anon' : 'auth'}';
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
