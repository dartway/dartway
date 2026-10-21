import 'dart:async';

import '../alerts/dw_server_logger.dart';
import '../outbound/dw_outbound_http.dart';
import 'dw_seam_cassette.dart';

/// What a test server's `ctx.http` talks to: records every request, asks
/// explicit rules first, then an attached [DwSeamCassette]. Unmatched requests
/// fail with [StateError]. Replay stays offline; only an explicitly attached
/// cassette in record or verify mode reaches a real service.
///
/// Every `DwTestServer` has one, `DwTestServer.http`:
///
/// ```dart
/// server.http.useCassette(DwSeamCassette('test/cassettes/sms.json'));
/// … // the command that sends the SMS
/// expect(server.http.requests.single.form['phones'], '79990000001');
/// ```
///
/// Handwritten rules are for exceptional outcomes, not coverage of a real
/// provider's contract.
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
/// final http = DwFakeOutboundHttp()
///   ..useCassette(DwSeamCassette('test/cassettes/sms.json'));
/// await SmsGateway(settings).send(http.client(), phone, text);
/// ```
final class DwFakeOutboundHttp implements DwOutboundTransport {
  final List<DwOutboundRequest> _requests = [];
  final List<_Rule> _rules = [];
  bool _closed = false;
  DwSeamCassette? _cassette;

  /// Uses recorded real answers; explicit rules take precedence.
  void useCassette(DwSeamCassette cassette) => _cassette = cassette;

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
    _cassette = null;
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
    if (_cassette case final cassette?) {
      return cassette.http(request, timeout, maxResponseBytes);
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
