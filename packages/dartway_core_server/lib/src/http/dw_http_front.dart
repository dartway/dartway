import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../calls/dw_call_endpoint.dart';
import '../context/dw_call_context.dart';
import '../live/dw_live_endpoint.dart';
import '../routes/dw_route.dart';
import '../server/dw_runtime.dart';
import '../server/dw_server_settings.dart';
import 'dw_http_request.dart';
import 'dw_http_response.dart';
import 'dw_reason_phrase.dart';
import 'dw_request_body.dart';

/// The server's one port: `dart:io`'s `HttpServer` and a routing table of
/// three framework paths and the project's doors, looked up by exact path.
@internal
final class DwHttpFront {
  DwHttpFront({
    required this.runtime,
    required this.settings,
    required this.calls,
    required this.live,
    required List<DwRoute> routes,
  }) : _routes = _indexRoutes(routes);

  final DwRuntime runtime;
  final DwServerSettings settings;
  final DwCallEndpoint calls;
  final DwLiveEndpoint live;

  /// Path → method (`null` for any) → route.
  final Map<String, Map<String?, DwRoute>> _routes;

  HttpServer? _server;
  bool _stopping = false;
  int _inFlight = 0;
  Completer<void>? _idle;

  DwServerLogger get _log => runtime.log;

  static const Map<String, String> _callHeaders = {
    DwHttpContract.contentTypeHeader: DwHttpContract.jsonContentType,
    // A call's answer is for its caller only — a session token, a private
    // row — and never for a cache between them.
    'cache-control': 'no-store',
  };

  static final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder();

  static Map<String, Map<String?, DwRoute>> _indexRoutes(List<DwRoute> routes) {
    final index = <String, Map<String?, DwRoute>>{};
    for (final route in routes) {
      (index[route.path] ??= {})[route.method] = route;
    }
    return index;
  }

  int get port =>
      (_server ?? (throw StateError('The server is not listening'))).port;

  Future<void> bind(InternetAddress address, int port) async {
    final server = await HttpServer.bind(address, port);
    server.idleTimeout = const Duration(seconds: 120);
    _server = server;
    server.listen(
      (request) => unawaited(_serve(request)),
      onError: (Object error) => _log.warning('HTTP listener', error: error),
    );
  }

  /// Stops accepting connections, lets the calls in flight finish within
  /// [timeout], and returns; [close] cuts what is left.
  Future<void> drain(Duration timeout) async {
    _stopping = true;
    // Stops listening; a keep-alive connection is closed after its current
    // response (`dart:io` does not keep one alive once the server is closed).
    await _server?.close();
    if (_inFlight == 0) return;
    await (_idle ??= Completer<void>()).future.timeout(
      timeout,
      onTimeout: () => _log.warning(
        '$_inFlight HTTP requests still running at stop timeout',
      ),
    );
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    if (path == DwHttpContract.livePath) {
      // An upgrade is not a call in flight: once accepted, the socket belongs
      // to the live hub, which the stop closes itself.
      try {
        await live.upgrade(request, stopping: _stopping);
      } catch (error) {
        _log.debug('live upgrade failed: $error');
        try {
          dwSetStatus(request.response, 400);
          await request.response.close();
        } catch (_) {
          // The connection is gone or already detached.
        }
      }
      return;
    }
    _inFlight++;
    final body = DwRequestBody(request, timeout: settings.bodyReadTimeout);
    try {
      final (status, headers, bytes) = switch (path) {
        DwHttpContract.healthPath => await _health(request),
        _ when path.startsWith(DwHttpContract.pathPrefix) => await _call(
          request,
          body,
        ),
        _ => await _route(request, body),
      };
      // Whatever a handler left unread is consumed before the answer, so the
      // peer can read it (see DwRequestBody).
      await body.discard();
      await _write(request, status, headers, bytes);
    } catch (error, stackTrace) {
      // Writing failed (the peer went away) or a bug above: nothing to
      // answer with, but never silent.
      _log.warning(
        'HTTP ${request.method} $path was not answered',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await request.response.close();
      } catch (_) {
        // Already closed.
      }
    } finally {
      _inFlight--;
      if (_inFlight == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  Future<void> _write(
    HttpRequest request,
    int status,
    Map<String, String> headers,
    List<int> bytes,
  ) async {
    final response = request.response;
    dwSetStatus(response, status);
    headers.forEach(response.headers.set);
    response.contentLength = bytes.length;
    if (_stopping) response.persistentConnection = false;
    response.add(bytes);
    await response.close();
  }

  Future<(int, Map<String, String>, List<int>)> _call(
    HttpRequest request,
    DwRequestBody body,
  ) async {
    var answer = await calls.answer(request, body);
    List<int> bytes;
    try {
      // Straight to UTF-8 bytes, without an intermediate string.
      bytes = _jsonUtf8.convert(answer.toJson());
    } catch (error, stackTrace) {
      // A result whose `toJson` holds something JSON cannot carry: a bug in
      // a codec, found by the call that returns it.
      answer = DwApiResponse.failed(
        runtime.alerts.report(
          where: 'encode ${request.uri.path}',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      bytes = _jsonUtf8.convert(answer.toJson());
    }
    return (
      dwHttpStatusFor(answer),
      {..._callHeaders, ...dwHttpHeadersFor(answer)},
      bytes,
    );
  }

  Future<(int, Map<String, String>, List<int>)> _health(
    HttpRequest request,
  ) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      return _text(405, 'method not allowed', {'allow': 'GET, HEAD'});
    }
    if (_stopping) return _text(503, 'stopping');
    try {
      await runtime.db.query('SELECT 1');
      return _text(200, 'ok');
    } catch (error) {
      _log.warning('health check: database unavailable', error: error);
      return _text(503, 'database unavailable');
    }
  }

  Future<(int, Map<String, String>, List<int>)> _route(
    HttpRequest request,
    DwRequestBody body,
  ) async {
    final byMethod = _routes[request.uri.path];
    if (byMethod == null) return _text(404, 'not found');
    final route = byMethod[request.method] ?? byMethod[null];
    if (route == null) {
      return _text(405, 'method not allowed', {
        'allow': byMethod.keys.whereType<String>().join(', '),
      });
    }
    final where = 'route $route';
    final (sessionKey, refused) = await _routeSession(request, route, where);
    if (refused != null) {
      return (refused.status, refused.headers, refused.body);
    }
    final ctx = runtime.context(
      scope: where,
      kind: DwContextKind.background,
      sessionKey: sessionKey,
    );
    DwHttpResponse response;
    try {
      response = await route.handle(
        ctx,
        DwHttpRequest(request, body, maxBodyBytes: settings.maxBodyBytes),
      );
    } on DwRequestBodyException catch (error) {
      response = DwHttpResponse.text(error.message, status: error.status);
    } on DwRefusalException catch (error) {
      final refusal = error.refusal;
      final answer = refusal.isIncompatibility
          ? DwApiResponse.incompatible(refusal)
          : DwApiResponse.refused(refusal);
      response = DwHttpResponse.json(
        {'refusal': refusal.toJson()},
        status: dwHttpStatusFor(answer),
        headers: dwHttpHeadersFor(answer),
      );
    } on DwNotAuthenticatedException {
      response = DwHttpResponse.empty(status: 401);
    } catch (error, stackTrace) {
      final incident = runtime.alerts.report(
        where: where,
        error: error,
        stackTrace: stackTrace,
      );
      response = DwHttpResponse.json({'incident': incident}, status: 500);
    } finally {
      runtime.deliver(ctx);
    }
    return (response.status, response.headers, response.body);
  }

  /// The session key of a route that authenticates, or the response that
  /// answers the request instead: 400 for an `Authorization` header that is
  /// not one bearer token, 401 for a token that is unknown or revoked (and for
  /// none, when the route requires one), 500 when resolving fails.
  Future<(DwSessionKeyInfo?, DwHttpResponse?)> _routeSession(
    HttpRequest request,
    DwRoute route,
    String where,
  ) async {
    if (route.auth == DwRouteAuth.none) return (null, null);
    const challenge = {'www-authenticate': 'Bearer'};
    final String? token;
    try {
      final values = request.headers[DwHttpContract.authorizationHeader];
      if (values != null && values.length > 1) {
        throw const _MalformedAuthorization('the header is repeated');
      }
      token = dwBearerToken(
        values?.single,
        (what) => throw _MalformedAuthorization(what),
      );
    } on _MalformedAuthorization catch (error) {
      _log.warning('$where: malformed Authorization: ${error.what}');
      return (
        null,
        DwHttpResponse.text('malformed Authorization', status: 400),
      );
    }
    if (token == null) {
      return route.auth == DwRouteAuth.required
          ? (null, DwHttpResponse.empty(status: 401, headers: challenge))
          : (null, null);
    }
    try {
      final key = await calls.authService.resolve(token);
      if (key == null) {
        return (null, DwHttpResponse.empty(status: 401, headers: challenge));
      }
      return (key, null);
    } catch (error, stackTrace) {
      final incident = runtime.alerts.report(
        where: '$where authenticate',
        error: error,
        stackTrace: stackTrace,
      );
      return (null, DwHttpResponse.json({'incident': incident}, status: 500));
    }
  }

  static (int, Map<String, String>, List<int>) _text(
    int status,
    String text, [
    Map<String, String> headers = const {},
  ]) => (
    status,
    {'content-type': 'text/plain; charset=utf-8', ...headers},
    utf8.encode(text),
  );
}

final class _MalformedAuthorization implements Exception {
  const _MalformedAuthorization(this.what);

  final String what;
}
