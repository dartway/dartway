import 'dart:async';

import '../context/dw_call_context.dart';
import '../http/dw_http_request.dart';
import '../http/dw_http_response.dart';

/// Handles one external HTTP door. `ctx` is a [DwCallContext], with the
/// caller's account and session key when the route authenticates
/// ([DwRouteAuth]), and without them otherwise. Publications and jobs are
/// allowed; they are delivered when the route answers.
typedef DwRouteHandler =
    FutureOr<DwHttpResponse> Function(
      DwCallContext ctx,
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
final class DwHttpRoute {
  const DwHttpRoute._(this.method, this.path, this.handle, this.auth);

  DwHttpRoute.get(
    String path,
    DwRouteHandler handle, {
    DwRouteAuth auth = DwRouteAuth.none,
  }) : this._('GET', path, handle, auth);

  DwHttpRoute.post(
    String path,
    DwRouteHandler handle, {
    DwRouteAuth auth = DwRouteAuth.none,
  }) : this._('POST', path, handle, auth);

  /// Every method; a route of the same path with a specific method wins.
  DwHttpRoute.any(
    String path,
    DwRouteHandler handle, {
    DwRouteAuth auth = DwRouteAuth.none,
  }) : this._(null, path, handle, auth);

  /// Upper case, or `null` for [DwHttpRoute.any].
  final String? method;
  final String path;
  final DwRouteHandler handle;

  /// Whether the route reads `Authorization: Bearer <token>` as a call does.
  final DwRouteAuth auth;

  @override
  String toString() => '${method ?? 'ANY'} $path';
}

/// How a route treats `Authorization: Bearer <token>` — the same session
/// tokens calls carry, app and personal keys alike.
enum DwRouteAuth {
  /// The header is not read: `ctx.accountId` and `ctx.sessionKey` are `null`.
  /// For doors whose callers prove themselves otherwise (a signed webhook).
  none,

  /// A valid token signs the route's context in; no header leaves it
  /// anonymous. A token that is unknown or revoked is answered 401 before the
  /// handler runs, as on a call — a caller holding a dead token must learn it.
  optional,

  /// As [optional], and no header is answered 401 too.
  required,
}
