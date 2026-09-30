import 'dart:async';

import '../alerts/dw_server_logger.dart';
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
///
/// A class that talks to a provider is unit-tested without a server through
/// [client], the same `DwOutboundHttp` a context hands it:
///
/// ```dart
/// final http = DwFakeOutboundHttp()..when((_) => true, (_) => DwOutboundResponse(200));
/// await SmsGateway(settings).send(http.client(), phone, text);
/// ```
final class DwFakeOutboundHttp implements DwOutboundTransport {
  final List<DwOutboundRequest> _requests = [];
  final List<_Rule> _rules = [];
  bool _closed = false;

  /// A `DwOutboundHttp` over this fake, for code tested without a server:
  /// what `ctx.http` is under a `DwTestServer`, with [timeout] and
  /// [maxResponseBytes] in place of the server's settings and [log] (the
  /// console by default) in place of the context's.
  DwOutboundHttp client({
    Duration timeout = const Duration(seconds: 30),
    int maxResponseBytes = 10 << 20,
    DwServerLogger log = const DwConsoleLogger(scope: 'outbound'),
  }) => DwOutboundHttp(
    this,
    log: log,
    timeout: timeout,
    maxResponseBytes: maxResponseBytes,
  );

  /// Whether the server that used it has stopped: it answers nothing more.
  bool get isClosed => _closed;

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
    int maxResponseBytes,
  ) async {
    if (_closed) throw StateError('DwFakeOutboundHttp is closed');
    _requests.add(request);
    for (final rule in _rules) {
      if (rule.matches(request)) return rule.respond(request);
    }
    throw StateError(
      'No DwFakeOutboundHttp rule answers ${request.method} ${request.origin}: '
      'script it with server.http.when(…)',
    );
  }

  @override
  void close() => _closed = true;
}

typedef _Rule = ({
  bool Function(DwOutboundRequest request) matches,
  FutureOr<DwOutboundResponse> Function(DwOutboundRequest request) respond,
});
