import 'dart:async';

import '../context/dw_call_context.dart';
import '../http/dw_http_request.dart';
import '../http/dw_http_response.dart';

/// The context of a project route: a [DwCallContext] without an account.
/// Publications and jobs are allowed; they are delivered when the route
/// answers.
typedef DwRouteContext = DwCallContext;

/// Handles one external HTTP door.
typedef DwRouteHandler =
    FutureOr<DwHttpResponse> Function(
      DwRouteContext ctx,
      DwHttpRequest request,
    );

/// An external HTTP door: a webhook, a payment callback, a file download.
/// The app itself calls `POST /dw/<name>`; routes exist for callers that
/// cannot.
///
/// Routes are matched by exact path: a map lookup, no patterns. `/dw/`,
/// `/dw` and `/health` are the framework's, and a route there fails the
/// server's startup.
///
/// What a route throws is answered for it: a `DwRequestBodyException` with
/// its status, a refusal with the refusal as JSON and the status of the same
/// refusal on a call (422, or 403/404/409/429), a
/// `DwNotAuthenticatedException` with 401, and anything else with 500 and
/// the incident id only — and an alert.
final class DwRoute {
  const DwRoute._(this.method, this.path, this.handle);

  DwRoute.get(String path, DwRouteHandler handle) : this._('GET', path, handle);

  DwRoute.post(String path, DwRouteHandler handle)
    : this._('POST', path, handle);

  /// Every method; a route of the same path with a specific method wins.
  DwRoute.any(String path, DwRouteHandler handle) : this._(null, path, handle);

  /// Upper case, or `null` for [DwRoute.any].
  final String? method;
  final String path;
  final DwRouteHandler handle;

  @override
  String toString() => '${method ?? 'ANY'} $path';
}
