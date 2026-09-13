/// A reason the server can refuse for. Declared by the project as an enum in its
/// shared package:
///
/// ```dart
/// enum AppRefusal with DwRefusalCodes { seatsNotEnough, bookingClosed }
/// ```
abstract interface class DwRefusalCode {
  /// The code on the wire.
  String get code;
}

/// Makes an enum a set of refusal codes; the code is the value's name.
mixin DwRefusalCodes on Enum implements DwRefusalCode {
  @override
  String get code => name;
}

/// The framework's own refusals. It ships no text for them: the project renders
/// every code, its own and these, through its string catalogue.
enum DwCoreRefusal implements DwRefusalCode {
  /// The caller may not do this.
  forbidden,

  /// The thing asked for does not exist, or the caller may not know it does.
  notFound,

  /// The state changed under the caller (a unique key, a stale version).
  conflict,

  /// The input is not acceptable; [DwRefusal.field] names the field.
  invalid,

  /// A subscription to a channel kind the server does not declare.
  unknownChannel,

  /// Asked too often. `retryAfter` holds whole seconds until asking again
  /// can succeed; build it with [DwRefusal.tooManyRequests] and read it with
  /// [DwRefusal.retryAfter].
  tooManyRequests,

  /// A one-time code can no longer be verified — its ticket is unknown, used,
  /// expired or out of attempts; [DwRefusal.field] is `code`. The user needs
  /// a new code, not another try.
  codeExpired;

  // There is deliberately no `failed` code. A refusal is an answer for the
  // user and never alerts; a failure is an incident with no detail. A
  // subscription whose check threw is a failure, so it travels as one —
  // `DwSubscriptionRefusedMessage.failed` with an incident id — rather than
  // as a refusal a screen would render as the user's fault.

  @override
  String get code => 'dw.$name';
}

/// A refusal: a code with parameters, never a sentence.
///
/// Permission checks, business rules and validation are all refusals — one
/// mechanism. A refusal reaches the user and never alerts the operator.
final class DwRefusal {
  DwRefusal(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    this.field,
  }) : code = code.code,
       params = {
         for (final entry in params.entries)
           if (entry.value != null) entry.key: '${entry.value}',
       };

  const DwRefusal.raw(this.code, {this.params = const {}, this.field});

  /// [DwCoreRefusal.tooManyRequests], asking to wait [retryAfter]: rounded up
  /// to whole seconds, and at least one — "retry in 0 s" would invite the
  /// request it refuses.
  factory DwRefusal.tooManyRequests(Duration retryAfter) {
    final seconds = (retryAfter.inMicroseconds / Duration.microsecondsPerSecond)
        .ceil();
    return DwRefusal(
      DwCoreRefusal.tooManyRequests,
      params: {_retryAfterParam: seconds < 1 ? 1 : seconds},
    );
  }

  static const String _retryAfterParam = 'retryAfter';

  /// The code on the wire: the project's enum value name, or `dw.*`.
  final String code;

  /// Values the rendered text needs (`{'left': '2'}`). Strings on the wire.
  final Map<String, String> params;

  /// The input field a validation refusal points at.
  final String? field;

  /// Whether this refusal carries [candidate].
  bool isCode(DwRefusalCode candidate) => code == candidate.code;

  /// How long to wait before asking again: set on
  /// [DwCoreRefusal.tooManyRequests], `null` on every other refusal (and on
  /// one whose parameter does not read as seconds).
  Duration? get retryAfter {
    if (!isCode(DwCoreRefusal.tooManyRequests)) return null;
    final seconds = int.tryParse(params[_retryAfterParam] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  Map<String, Object?> toJson() => {
    'code': code,
    if (params.isNotEmpty) 'params': params,
    if (field != null) 'field': field,
  };

  static DwRefusal fromJson(Map<String, Object?> json) => DwRefusal.raw(
    json['code']! as String,
    params:
        (json['params'] as Map<String, Object?>?)?.map(
          (key, value) => MapEntry(key, value! as String),
        ) ??
        const {},
    field: json['field'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is DwRefusal &&
      other.code == code &&
      other.field == field &&
      _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    code,
    field,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'DwRefusal($code${params.isEmpty ? '' : ' $params'}${field == null ? '' : ' @$field'})';
}

/// Thrown by server code to refuse; the framework turns it into a refused result.
final class DwRefusalException implements Exception {
  DwRefusalException(this.refusal);

  final DwRefusal refusal;

  @override
  String toString() => 'DwRefusalException($refusal)';
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
