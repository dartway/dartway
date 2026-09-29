import 'dart:async';

import '../outbound/dw_outbound_http.dart';

/// What a test server's `ctx.http` talks to instead of the network: it
/// records every request and answers each from the rules the test gave it.
///
/// Every `DwTestServer` has one, `DwTestServer.http`, and with no rule it
/// answers nothing — a request no rule matches fails the call that made it
/// with a [StateError] naming the request, so a test never reaches the
/// network by accident:
///
/// ```dart
/// server.http.when(
///   (request) => request.url.host == 'sms.example.com',
///   (request) => DwOutboundResponse(200, json: {'id': 7}),
/// );
/// … // the command that sends the SMS
/// expect(server.http.requests.single.form['phones'], '79990000001');
/// ```
///
/// A rule answers with a response, or throws — a [DwOutboundException] is
/// how a test makes the provider unreachable; a rule whose future never
/// completes runs into the call's timeout. The rule added last is asked
/// first, so a test overrides what its harness scripted.
final class DwFakeOutboundHttp implements DwOutboundTransport {
  final List<DwOutboundRequest> _requests = [];
  final List<_Rule> _rules = [];

  /// Every request sent, answered or not, oldest first.
  List<DwOutboundRequest> get requests => List.unmodifiable(_requests);

  /// Answers requests [matches] accepts with [respond].
  void when(
    bool Function(DwOutboundRequest request) matches,
    FutureOr<DwOutboundResponse> Function(DwOutboundRequest request) respond,
  ) => _rules.insert(0, (matches: matches, respond: respond));

  /// Forgets the requests and the rules.
  void reset() {
    _requests.clear();
    _rules.clear();
  }

  @override
  Future<DwOutboundResponse> exchange(
    DwOutboundRequest request,
    Duration timeout,
  ) async {
    _requests.add(request);
    for (final rule in _rules) {
      if (rule.matches(request)) return rule.respond(request);
    }
    throw StateError(
      'No DwFakeOutboundHttp rule answers ${request.method} ${request.url}: '
      'script it with server.http.when(…)',
    );
  }

  @override
  void close() {}
}

typedef _Rule = ({
  bool Function(DwOutboundRequest request) matches,
  FutureOr<DwOutboundResponse> Function(DwOutboundRequest request) respond,
});
