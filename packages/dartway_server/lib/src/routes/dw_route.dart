import 'dart:async';
import 'dart:convert';

import 'package:relic/relic.dart';

import '../context/dw_context.dart';

/// The context of a web route: a [DwContext] without an account.
typedef DwRouteContext = DwContext;

/// Handles one external HTTP door.
typedef DwRouteHandler =
    FutureOr<Response> Function(DwRouteContext ctx, Request request);

/// An external HTTP door (a webhook, a file download). The app itself talks
/// over the WebSocket at `/dw`; routes exist for callers that cannot.
///
/// A route that throws answers 500 with only the incident id; a
/// `DwRefusalException` answers 400 with the refusal.
final class DwRoute {
  const DwRoute._(this.method, this.path, this.handle);

  DwRoute.get(String path, DwRouteHandler handle)
    : this._(Method.get, path, handle);

  DwRoute.post(String path, DwRouteHandler handle)
    : this._(Method.post, path, handle);

  final Method method;
  final String path;
  final DwRouteHandler handle;

  /// A JSON response.
  static Response json(Object? body, {int status = 200}) => Response(
    status,
    body: Body.fromString(jsonEncode(body), mimeType: MimeType.json),
  );

  /// Reads the request body as a JSON object, refusing bodies over [maxBytes].
  /// Throws `FormatException` when the body is not a JSON object.
  static Future<Map<String, Object?>> readJson(
    Request request, {
    int maxBytes = 1 << 20,
  }) async {
    final text = await request.readAsString(maxLength: maxBytes);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }
}
