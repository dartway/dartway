import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// An external command, without shell expansion. Environment entries override
/// the inherited environment; only these explicit entries enter a cassette.
final class DwProcessRequest {
  DwProcessRequest(
    this.executable,
    List<String> arguments, {
    this.workingDirectory,
    Map<String, String> environment = const {},
  }) : arguments = List.unmodifiable(arguments),
       environment = Map.unmodifiable(environment);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
}

/// A completed command. A nonzero exit is a result, not a transport failure.
final class DwProcessResult {
  const DwProcessResult(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout;
  final String stderr;
}

/// A command could not start, timed out, or exceeded its output limit.
/// Arguments and output never appear in this error: they can contain secrets.
final class DwProcessException implements Exception {
  const DwProcessException(this.reason);
  final String reason;
  @override
  String toString() => 'DwProcessException: $reason';
}

/// The server's external command seam (`ctx.process`). Tests replace its
/// transport at the server, including commands made by routes and jobs.
final class DwProcessRunner {
  @internal
  const DwProcessRunner(this._transport);
  final DwProcessTransport _transport;

  Future<DwProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    Duration timeout = const Duration(seconds: 30),
    int maxOutputBytes = 10 << 20,
  }) {
    if (timeout <= Duration.zero || maxOutputBytes <= 0) {
      throw ArgumentError('Command timeout and output limit must be positive');
    }
    return _transport.run(
      DwProcessRequest(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      ),
      timeout,
      maxOutputBytes,
    );
  }
}

@internal
abstract interface class DwProcessTransport {
  Future<DwProcessResult> run(
    DwProcessRequest request,
    Duration timeout,
    int maxOutputBytes,
  );
}

@internal
final class DwSystemProcess implements DwProcessTransport {
  const DwSystemProcess();

  @override
  Future<DwProcessResult> run(
    DwProcessRequest request,
    Duration timeout,
    int maxOutputBytes,
  ) async {
    final watch = Stopwatch()..start();
    final Process process;
    try {
      process = await Process.start(
        request.executable,
        request.arguments,
        workingDirectory: request.workingDirectory,
        environment: request.environment,
      );
    } on ProcessException {
      throw const DwProcessException('could not start command');
    }
    final out = <int>[];
    final err = <int>[];
    var bytes = 0;
    final failure = Completer<DwProcessResult>();
    void collect(List<int> chunk, List<int> target) {
      bytes += chunk.length;
      if (bytes > maxOutputBytes) {
        if (!failure.isCompleted) {
          failure.completeError(
            const DwProcessException('output limit exceeded'),
          );
        }
        process.kill(ProcessSignal.sigkill);
      } else {
        target.addAll(chunk);
      }
    }

    final outDone = Completer<void>();
    final errDone = Completer<void>();
    final stdout = process.stdout.listen(
      (chunk) => collect(chunk, out),
      onDone: outDone.complete,
      onError: outDone.completeError,
    );
    final stderr = process.stderr.listen(
      (chunk) => collect(chunk, err),
      onDone: errDone.complete,
      onError: errDone.completeError,
    );
    // Close stdin without delaying installation of the output/error listeners.
    final inputClosed = process.stdin.close();
    final remaining = timeout - watch.elapsed;
    final timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!failure.isCompleted) {
        failure.completeError(const DwProcessException('command timed out'));
      }
      process.kill(ProcessSignal.sigkill);
    });
    try {
      return await Future.any([
        () async {
          await inputClosed;
          final code = await process.exitCode;
          await Future.wait([outDone.future, errDone.future]);
          return DwProcessResult(
            code,
            utf8.decode(out, allowMalformed: true),
            utf8.decode(err, allowMalformed: true),
          );
        }(),
        failure.future,
      ]);
    } finally {
      timer.cancel();
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      await stdout.cancel();
      await stderr.cancel();
    }
  }
}
