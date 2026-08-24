import 'dart:io';

import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'dw_proxy_settings.dart';

/// The outbound HTTP client alerts are sent through when the server cannot
/// reach `api.telegram.org` itself.
///
/// Lives on the server and nowhere else: it is `dart:io` from top to bottom,
/// and a proxy is a property of the machine the server runs on, not of the
/// app. The Flutter half of the core never sees it — which is also why
/// `DwAlerts` takes a plain `http.Client` rather than anything of this shape.
abstract final class DwProxyHttpClient {
  /// How long a connection to the proxy itself may take to establish.
  ///
  /// The send has its own deadline (`DwTelegramService.sendTimeout`); this one
  /// covers the leg before it, where a proxy that has gone away leaves the
  /// connect hanging.
  static const connectionTimeout = Duration(seconds: 10);

  /// Builds a proxying client from [env] (typically the app's `passwords.yaml`).
  ///
  /// Returns null when
  /// [DwTelegramAlertsKeys.dwTelegramAlertsProxyUrlKey] is absent, blank, or
  /// not a proxy URL — and null is not a failure, it is the default: it hands
  /// `DwAlerts` no client, and alerts then go out directly, exactly as they did
  /// before the key existed.
  ///
  /// ```dart
  /// dwAlerts: DwAlerts.init(
  ///   telegramConfig: DwTelegramAlertsConfig.fromEnv(env: passwords),
  ///   httpClient: DwProxyHttpClient.fromEnv(env: passwords),
  /// ),
  /// ```
  ///
  /// The client is meant to live as long as the process — `DwAlerts` keeps it
  /// and reuses it for every alert. Nothing closes it, deliberately: the sink
  /// outlives every send that goes through it.
  static http.Client? fromEnv({
    required Map<String, String> env,
    void Function(String message)? logFunction,
  }) {
    final settings = DwProxySettings.parse(
      env[DwTelegramAlertsKeys.dwTelegramAlertsProxyUrlKey],
      logFunction: logFunction,
    );

    if (settings == null) return null;

    logFunction?.call(
      'DwProxyHttpClient: alerts go through ${settings.host}:${settings.port}'
      '${settings.hasCredentials ? ' (authenticated)' : ''}.',
    );

    return IOClient(_buildHttpClient(settings));
  }

  static HttpClient _buildHttpClient(DwProxySettings settings) {
    final client = HttpClient()
      ..connectionTimeout = connectionTimeout
      ..findProxy = (_) => settings.proxyConfiguration;

    if (settings.hasCredentials) {
      // The empty realm is not a placeholder: `dart:io` matches proxy
      // credentials by host and port, and consults the realm only for the
      // challenge a proxy sends back.
      client.addProxyCredentials(
        settings.host,
        settings.port,
        '',
        HttpClientBasicCredentials(settings.username!, settings.password!),
      );
    }

    return client;
  }
}
