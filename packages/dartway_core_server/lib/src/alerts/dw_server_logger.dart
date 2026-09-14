import 'dart:io';

/// How much a log line matters.
enum DwLogLevel { debug, info, warning, error }

/// The server's log. One interface for the framework and for handlers, so a
/// project that ships logs somewhere replaces one object and sees everything.
///
/// Never pass codes, tokens or DTO contents: the framework itself logs type
/// names and ids only, and a handler that logs a secret has leaked it.
abstract interface class DwServerLogger {
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });

  /// A logger that prefixes every line with [scope] (a call, a job).
  DwServerLogger scoped(String scope);
}

/// Convenience methods over [DwServerLogger.log].
extension DwLoggerLevels on DwServerLogger {
  void debug(String message) => log(DwLogLevel.debug, message);
  void info(String message) => log(DwLogLevel.info, message);
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      log(DwLogLevel.warning, message, error: error, stackTrace: stackTrace);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(DwLogLevel.error, message, error: error, stackTrace: stackTrace);
}

/// Writes to stdout (below warning) and stderr (warning and above), one line
/// per entry plus the stack trace when there is one.
final class DwConsoleLogger implements DwServerLogger {
  const DwConsoleLogger({this.minLevel = DwLogLevel.info, this.scope});

  final DwLogLevel minLevel;
  final String? scope;

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final buffer = StringBuffer()
      ..write(DateTime.now().toUtc().toIso8601String())
      ..write(' ')
      ..write(level.name.toUpperCase())
      ..write(scope == null ? ' ' : ' [$scope] ')
      ..write(message);
    if (error != null) buffer.write(': $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    final sink = level.index >= DwLogLevel.warning.index ? stderr : stdout;
    sink.writeln(buffer);
  }

  @override
  DwServerLogger scoped(String scope) => DwConsoleLogger(
    minLevel: minLevel,
    scope: this.scope == null ? scope : '${this.scope} $scope',
  );
}
