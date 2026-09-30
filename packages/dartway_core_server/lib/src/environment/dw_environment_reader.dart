import 'package:meta/meta.dart';

/// The server's environment did not configure it: every variable that is
/// missing or unreadable, listed at once.
///
/// Thrown by [DwEnvironmentReader.read] before anything is built from a
/// half-read environment. A secret's value never appears in it.
final class DwEnvironmentException implements Exception {
  DwEnvironmentException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      'DwEnvironmentException: the environment does not configure the '
      'server:\n${problems.map((problem) => '  - $problem').join('\n')}';
}

/// Reads typed values out of the process environment, and fails once with
/// everything that is wrong.
///
/// A project reads its variables in exactly one place,
/// `lib/src/core/environment.dart`, into one typed object built at start:
///
/// ```dart
/// final class AppEnvironment {
///   AppEnvironment({required this.server, required this.sms});
///
///   static AppEnvironment read(Map<String, String> variables) =>
///       DwEnvironmentReader.read(variables, (read) => AppEnvironment(
///         server: DwServerEnvironment.read(read),
///         sms: AppSmsEnvironment(
///           login: read.required('SMS_LOGIN'),
///           password: read.required('SMS_PASSWORD'),
///           sender: read.optional('SMS_SENDER'),
///         ),
///       ));
///
///   final DwServerEnvironment server;
///   final AppSmsEnvironment sms;
/// }
/// ```
///
/// Each accessor answers at once — a placeholder when the value is missing
/// or malformed — and records the problem; [read] throws
/// [DwEnvironmentException] with every problem after the object is built, so
/// a deploy that forgot three variables hears about all three in one start
/// instead of one per restart, and nothing ever sees the placeholder.
///
/// A problem names the variable and what is wrong with it. A text value is
/// never repeated — text is where passwords and tokens live, and a missing
/// one has nothing to show; a number or a flag that does not parse is shown,
/// unless it is read with `secret: true`.
final class DwEnvironmentReader {
  DwEnvironmentReader._(this._variables);

  final Map<String, String> _variables;
  final List<String> _problems = [];

  /// Builds a value with [build] from [variables] — the process environment,
  /// through `DwLocalEnvironment.overlay` on a developer's machine — and
  /// throws [DwEnvironmentException] listing every problem any accessor or
  /// [report] recorded.
  static T read<T>(
    Map<String, String> variables,
    T Function(DwEnvironmentReader read) build,
  ) {
    final reader = DwEnvironmentReader._(variables);
    final value = build(reader);
    if (reader._problems.isNotEmpty) {
      throw DwEnvironmentException(List.unmodifiable(reader._problems));
    }
    return value;
  }

  /// The variables as given, for a framework reader of its own group
  /// (`DwDatabaseConfig.fromEnvironment`).
  @internal
  Map<String, String> get variables => _variables;

  /// [name]'s value; a problem when it is unset or empty.
  String required(String name) => _value(name) ?? _missing(name, '');

  /// [name]'s value, or `null` when it is unset or empty.
  String? optional(String name) => _value(name);

  /// [name] as an integer: [fallback] when it is unset, and a problem when it
  /// is unset without one or is not an integer.
  int integer(String name, {int? fallback, bool secret = false}) {
    final raw = _value(name);
    if (raw == null) return fallback ?? _missing(name, 0);
    return int.tryParse(raw) ??
        _invalid(name, raw, secret, 'must be an integer', 0);
  }

  /// [name] as `true` or `false` (any case): [fallback] when it is unset, and
  /// a problem when it is anything else.
  bool flag(String name, {bool fallback = false, bool secret = false}) {
    final raw = _value(name);
    if (raw == null) return fallback;
    return switch (raw.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => _invalid(name, raw, secret, 'must be "true" or "false"', fallback),
    };
  }

  /// [name] split at [separator], each entry trimmed and empty ones dropped;
  /// empty when it is unset.
  List<String> list(String name, {String separator = ','}) => [
    for (final entry in (_value(name) ?? '').split(separator))
      if (entry.trim() case final item when item.isNotEmpty) item,
  ];

  /// Records a problem no single accessor can see — two variables that must
  /// be set together, a value the project refuses:
  ///
  /// ```dart
  /// if ((projectId == null) != (token == null)) {
  ///   read.report('PUSH_PROJECT_ID and PUSH_TOKEN go together, or neither');
  /// }
  /// ```
  ///
  /// Never put a secret's value in [problem].
  void report(String problem) => _problems.add(problem);

  String? _value(String name) => switch (_variables[name]) {
    final value? when value.isNotEmpty => value,
    _ => null,
  };

  T _missing<T>(String name, T placeholder) {
    _problems.add('$name is not set');
    return placeholder;
  }

  T _invalid<T>(
    String name,
    String raw,
    bool secret,
    String expectation,
    T placeholder,
  ) {
    _problems.add(
      secret
          ? '$name $expectation (the value is secret and not shown)'
          : '$name $expectation, got "$raw"',
    );
    return placeholder;
  }
}
