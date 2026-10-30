import 'dart:convert';

/// The single wire contract used by the Flutter error reporter and server.
final class DwClientErrorReport {
  const DwClientErrorReport({
    required this.deviceId,
    required this.errorType,
    required this.error,
    required this.stackTrace,
    required this.platform,
    required this.appVersion,
    required this.route,
    required this.featureIds,
    required this.entries,
    required this.count,
  });

  static const maxBodyBytes = 32 << 10;
  static const maxDeviceIdBytes = 128;
  static const maxErrorTypeBytes = 128;
  static const maxErrorBytes = 4096;
  static const maxStackTraceBytes = 16 << 10;
  static const maxPlatformBytes = 32;
  static const maxAppVersionBytes = 64;
  static const maxRouteBytes = 512;
  static const maxFeatureIds = 50;
  static const maxFeatureIdBytes = 128;
  static const maxEntries = 25;
  static const maxEntryKeyBytes = 64;
  static const maxEntryValueBytes = 512;
  static const maxCount = 1000000;

  final String deviceId;
  final String errorType;
  final String error;
  final String stackTrace;
  final String platform;
  final String? appVersion;
  final String? route;
  final List<String> featureIds;
  final Map<String, String> entries;
  final int count;

  /// Builds the bounded representation used by the client.
  factory DwClientErrorReport.bounded({
    required String deviceId,
    required String errorType,
    required String error,
    required String stackTrace,
    required String platform,
    String? appVersion,
    String? route,
    required Iterable<String> featureIds,
    required Map<String, String> entries,
    required int count,
  }) {
    var report = DwClientErrorReport(
      deviceId: _truncate(deviceId, maxDeviceIdBytes),
      errorType: _truncate(errorType, maxErrorTypeBytes),
      error: _truncate(error, maxErrorBytes),
      stackTrace: _truncate(stackTrace, maxStackTraceBytes),
      platform: _truncate(platform, maxPlatformBytes),
      appVersion: _nullableTruncate(appVersion, maxAppVersionBytes),
      route: _nullableTruncate(route, maxRouteBytes),
      featureIds: featureIds
          .take(maxFeatureIds)
          .map((value) => _truncate(value, maxFeatureIdBytes))
          .toList(),
      entries: Map.fromEntries(
        entries.entries
            .take(maxEntries)
            .map(
              (entry) => MapEntry(
                _truncate(entry.key, maxEntryKeyBytes),
                _truncate(entry.value, maxEntryValueBytes),
              ),
            ),
      ),
      count: count.clamp(1, maxCount),
    );
    while (utf8.encode(jsonEncode(report.toJson())).length > maxBodyBytes) {
      if (report.stackTrace.isNotEmpty) {
        report = report._copy(stackTrace: _halve(report.stackTrace));
      } else if (report.error.isNotEmpty) {
        report = report._copy(error: _halve(report.error));
      } else if (report.route?.isNotEmpty ?? false) {
        report = report._copy(route: _halve(report.route!));
      } else if (report.entries.isNotEmpty) {
        final shortened = Map<String, String>.of(report.entries);
        final key = shortened.keys.last;
        final value = shortened[key]!;
        if (value.isNotEmpty) {
          shortened[key] = _halve(value);
        } else {
          shortened.remove(key);
        }
        report = report._copy(entries: shortened);
      } else if (report.featureIds.isNotEmpty) {
        report = report._copy(
          featureIds: report.featureIds.sublist(
            0,
            report.featureIds.length - 1,
          ),
        );
      } else {
        break;
      }
    }
    return report;
  }

  static DwClientErrorReport? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    String? field(String name, int max, {bool required = false}) {
      final item = value[name];
      if (item == null && !required) return null;
      return item is String &&
              (!required || item.isNotEmpty) &&
              utf8.encode(item).length <= max
          ? item
          : null;
    }

    final deviceId = field('deviceId', maxDeviceIdBytes, required: true);
    final errorType = field('errorType', maxErrorTypeBytes, required: true);
    final error = field('error', maxErrorBytes, required: true);
    final stackTrace = field('stackTrace', maxStackTraceBytes) ?? '';
    final platform = field('platform', maxPlatformBytes, required: true);
    final appVersion = field('appVersion', maxAppVersionBytes);
    final route = field('route', maxRouteBytes);
    final features = value['featureIds'];
    final rawEntries = value['entries'];
    final count = value['count'];
    if (deviceId == null ||
        errorType == null ||
        error == null ||
        platform == null ||
        (value.containsKey('appVersion') && appVersion == null) ||
        (value.containsKey('route') && route == null) ||
        (value.containsKey('stackTrace') &&
            field('stackTrace', maxStackTraceBytes) == null) ||
        count is! int ||
        count < 1 ||
        count > maxCount ||
        features is! List ||
        features.length > maxFeatureIds ||
        features.any(
          (item) =>
              item is! String || utf8.encode(item).length > maxFeatureIdBytes,
        ) ||
        rawEntries is! Map ||
        rawEntries.length > maxEntries ||
        rawEntries.entries.any(
          (entry) =>
              entry.key is! String ||
              entry.value is! String ||
              utf8.encode(entry.key as String).length > maxEntryKeyBytes ||
              utf8.encode(entry.value as String).length > maxEntryValueBytes,
        )) {
      return null;
    }
    return DwClientErrorReport(
      deviceId: deviceId,
      errorType: errorType,
      error: error,
      stackTrace: stackTrace,
      platform: platform,
      appVersion: appVersion,
      route: route,
      featureIds: features.cast<String>(),
      entries: rawEntries.cast<String, String>(),
      count: count,
    );
  }

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'errorType': errorType,
    'error': error,
    if (stackTrace.isNotEmpty) 'stackTrace': stackTrace,
    'platform': platform,
    if (appVersion != null) 'appVersion': appVersion,
    if (route != null) 'route': route,
    'featureIds': featureIds,
    'entries': entries,
    'count': count,
  };

  DwClientErrorReport _copy({
    String? error,
    String? stackTrace,
    String? route,
    List<String>? featureIds,
    Map<String, String>? entries,
  }) => DwClientErrorReport(
    deviceId: deviceId,
    errorType: errorType,
    error: error ?? this.error,
    stackTrace: stackTrace ?? this.stackTrace,
    platform: platform,
    appVersion: appVersion,
    route: route ?? this.route,
    featureIds: featureIds ?? this.featureIds,
    entries: entries ?? this.entries,
    count: count,
  );

  static String? _nullableTruncate(String? value, int bytes) =>
      value == null ? null : _truncate(value, bytes);
  static String _halve(String value) =>
      _truncate(value, utf8.encode(value).length ~/ 2);
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
}
