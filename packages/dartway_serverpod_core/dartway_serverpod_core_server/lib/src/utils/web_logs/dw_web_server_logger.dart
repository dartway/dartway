import 'dart:convert';
import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';
import '../../private/dw_singleton.dart';

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
      final failure = failureFor(e);

      error = e.toString();
      status = 'error';
      statusCode = failure.statusCode;

      if (failure.alert) {
        dw.alerts.reportError('❌ $handler failed', exception: e, stackTrace: st);
      }

      request.response
        ..statusCode = failure.statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': false, 'error': failure.message}));

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
        dw.alerts.reportError(
          '⚠️ Failed to write DwWebServerLog',
          exception: e,
          stackTrace: st,
        );
      }
    }
  }

  /// What the caller is told about [error], and whether it is an incident.
  ///
  /// The whole security question of a web route sits in this one line, so it
  /// is a function rather than two branches inside a `try`: it can be checked
  /// without a server, a session or a socket.
  ///
  /// A [DwPublicWebException] was written for the caller and goes to the caller
  /// — and raises no alert, because the route refusing on its own terms is not
  /// an incident. Anything else was written for us: a database error carries
  /// its query, a null check carries a file path, and whoever called a webhook
  /// is not somebody we authenticated. The caller is told that it failed; the
  /// text lives in the alert and in the [DwWebServerLog] row, where it is of
  /// use.
  @visibleForTesting
  static ({int statusCode, String message, bool alert}) failureFor(
    Object error,
  ) => error is DwPublicWebException
      ? (statusCode: error.statusCode, message: error.message, alert: false)
      : (
          statusCode: HttpStatus.internalServerError,
          message: 'Internal error. The failure has been recorded.',
          alert: true,
        );

  /// The body as it is written to [DwWebServerLog] — sensitive values replaced.
  ///
  /// Exposed for the test rather than for callers: a walk that misses a shape
  /// writes a secret into a table and nothing fails, which is not something to
  /// find out from a log review.
  @visibleForTesting
  static String? sanitizeBody(String? body, List<String> keys) =>
      _sanitizeBody(body, keys);

  static bool _isSensitiveKey(String key, List<String> keys) {
    final lower = key.toLowerCase();

    return keys.any((k) => lower == k.toLowerCase());
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

  static String? _sanitizeBody(String? body, List<String> extraKeys) {
    if (body == null) return null;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      // Lists as well as maps. A payload keeps its secrets one level inside an
      // array as readily as under a key — `{"items":[{"token":"…"}]}` — and a
      // walk that stops at maps writes that token into the log table intact,
      // with nothing failing.
      void sanitizeValue(Object? value) {
        if (value is Map<String, dynamic>) {
          for (final key in value.keys.toList()) {
            if (_isSensitiveKey(key, extraKeys)) {
              value[key] = _sensitiveValue;
            } else {
              sanitizeValue(value[key]);
            }
          }
        } else if (value is List) {
          for (final item in value) {
            sanitizeValue(item);
          }
        }
      }

      sanitizeValue(decoded);
      return jsonEncode(decoded);
    } catch (_) {
      // Non-JSON bodies are never logged
      return null;
    }
  }
}
