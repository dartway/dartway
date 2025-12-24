import 'dart:convert';
import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Universal web request logger for Serverpod routes.
/// Handles reading the body once, error handling, and DB logging.
class DwWebServerLogger {
  static const String _sensitiveValue = '***HIDDEN***';

  static const List<String> knownSensitiveKeys = [
    'authorization',
    'cookie',
    'set-cookie',
    'x-webhook-secret',
    'x-api-key',
    'password',
    'pass',
    'pwd',
    'token',
    'secret',
  ];

  /// Wraps any HTTP handler with logging and error tracking.
  ///
  /// [action] receives the already-read body (may be null for GET requests).
  ///
  /// Example:
  /// ```dart
  /// return DwWebServerLogger.handle(
  ///   session,
  ///   request,
  ///   handler: 'CreateUserRoute',
  ///   action: (body) async {
  ///     final data = jsonDecode(body ?? '{}');
  ///     ...
  ///     return true;
  ///   },
  /// );
  /// ```
  static Future<bool> handleWithExceptions(
    Session session,
    HttpRequest request, {
    required String handler,
    required Future<Map<String, dynamic>> Function(String? body) action,
    List<String> sensitiveKeys = knownSensitiveKeys,
  }) async {
    final start = DateTime.now();

    String? requestBody;
    String? status;
    String? error;
    int? statusCode;

    try {
      // --- 1. Read body only once
      if (request.method == 'POST' ||
          request.method == 'PUT' ||
          request.method == 'PATCH') {
        try {
          requestBody = await utf8.decoder.bind(request).join();
        } catch (e) {
          session.log(
            '⚠️ Failed to read request body: $e',
            level: LogLevel.warning,
          );
        }
      }

      // --- 2. Run main handler with body passed in
      final result = await action(requestBody);
      status = 'success';
      statusCode = request.response.statusCode;

      final response = {'success': true, 'data': result};

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response));

      return true;
    } catch (e, st) {
      error = e.toString();
      status = 'error';
      statusCode = HttpStatus.internalServerError;

      DwCore.instance.alerts.reportError(
        '❌ $handler failed',
        exception: e,
        stackTrace: st,
      );

      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': false, 'error': e.toString()}));

      return true;
    } finally {
      try {
        final headersMap = <String, String>{};
        request.headers.forEach((name, values) {
          headersMap[name] = values.join(',');
        });

        final sanitizedHeaders = _sanitizeHeaders(headersMap, sensitiveKeys);

        final sanitizedBody = _sanitizeBody(requestBody, sensitiveKeys);

        final durationMs = DateTime.now().difference(start).inMilliseconds;

        await DwWebServerLog.db.insertRow(
          session,
          DwWebServerLog(
            createdAt: start,
            method: request.method,
            url: request.uri.toString(),
            headers: jsonEncode(sanitizedHeaders),
            body: sanitizedBody,
            statusCode: statusCode,
            status: status,
            error: error,
            durationMs: durationMs,
            handler: handler,
            ip: request.connectionInfo?.remoteAddress.address,
          ),
        );
      } catch (e, st) {
        DwCore.instance.alerts.reportError(
          '⚠️ Failed to write DwWebServerLog',
          exception: e,
          stackTrace: st,
        );
      }
    }
  }

  static bool _isSensitiveKey(String key, List<String> keys) {
    final lower = key.toLowerCase();

    return keys.any(
      (k) => lower == k.toLowerCase(),
    );
  }

  static Map<String, String> _sanitizeHeaders(
    Map<String, String> headers,
    List<String> extraKeys,
  ) {
    return headers.map((key, value) {
      return MapEntry(
        key,
        _isSensitiveKey(key, extraKeys) ? _sensitiveValue : value,
      );
    });
  }

  static String? _sanitizeBody(
    String? body,
    List<String> extraKeys,
  ) {
    if (body == null) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      void sanitizeMap(Map<String, dynamic> map) {
        for (final key in map.keys.toList()) {
          if (_isSensitiveKey(key, extraKeys)) {
            map[key] = _sensitiveValue;
          } else if (map[key] is Map<String, dynamic>) {
            sanitizeMap(map[key] as Map<String, dynamic>);
          }
        }
      }

      sanitizeMap(decoded);
      return jsonEncode(decoded);
    } catch (_) {
      // Non-JSON bodies are never logged
      return null;
    }
  }
}
