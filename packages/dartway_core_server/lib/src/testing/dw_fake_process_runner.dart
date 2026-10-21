import 'dart:async';
import 'dart:convert';

import '../process/dw_process_runner.dart';
import 'dw_seam_cassette.dart';

/// Offline command transport. Unscripted commands fail without starting a process.
final class DwFakeProcessRunner implements DwProcessTransport {
  final _requests = <DwProcessRequest>[];
  final _rules =
      <
        (
          bool Function(DwProcessRequest),
          FutureOr<DwProcessResult> Function(DwProcessRequest),
        )
      >[];
  DwSeamCassette? _cassette;

  List<DwProcessRequest> get requests => List.unmodifiable(_requests);
  DwProcessRunner client() => DwProcessRunner(this);
  void useCassette(DwSeamCassette cassette) => _cassette = cassette;
  void when(
    bool Function(DwProcessRequest) matches,
    FutureOr<DwProcessResult> Function(DwProcessRequest) respond,
  ) => _rules.insert(0, (matches, respond));
  void reset() {
    _requests.clear();
    _rules.clear();
    _cassette = null;
  }

  @override
  Future<DwProcessResult> run(
    DwProcessRequest request,
    Duration timeout,
    int maxOutputBytes,
  ) async {
    _requests.add(request);
    final DwProcessResult response;
    final rule = _rules.where((rule) => rule.$1(request)).firstOrNull;
    if (rule != null) {
      response = await Future.sync(() => rule.$2(request)).timeout(
        timeout,
        onTimeout: () => throw const DwProcessException('command timed out'),
      );
    } else if (_cassette case final cassette?) {
      response = await cassette.process(request, timeout, maxOutputBytes);
    } else {
      throw StateError(
        'No command cassette or rule answers ${request.executable}; use server.process.useCassette(…)',
      );
    }
    if (utf8.encode(response.stdout).length +
            utf8.encode(response.stderr).length >
        maxOutputBytes) {
      throw const DwProcessException('output limit exceeded');
    }
    return response;
  }
}
