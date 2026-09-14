/// Strict reads of the framework's own JSON envelopes.
///
/// Generated DTO codecs cast (`json['x']! as int`) and let a `TypeError` name
/// the field; the envelopes around them — results, transports, responses,
/// live messages — are read by the framework, and a malformed one must fail
/// as a [FormatException] the caller can answer as a malformed message
/// rather than crash with a cast error. Not exported.
library;

Map<String, Object?> dwReadMap(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw FormatException('$what must be a JSON object, got ${_describe(json)}');
}

List<Object?> dwReadList(Object? json, String what) {
  if (json is List<Object?>) return json;
  throw FormatException('$what must be a JSON array, got ${_describe(json)}');
}

int dwReadInt(Object? json, String what) {
  if (json is int) return json;
  throw FormatException('$what must be an integer, got ${_describe(json)}');
}

bool dwReadBool(Object? json, String what) {
  if (json is bool) return json;
  throw FormatException('$what must be a boolean, got ${_describe(json)}');
}

String dwReadString(Object? json, String what) {
  if (json is String) return json;
  throw FormatException('$what must be a string, got ${_describe(json)}');
}

String? dwReadOptionalString(Object? json, String what) =>
    json == null ? null : dwReadString(json, what);

/// Rejects keys a message kind does not define: a misspelt key that is
/// silently ignored reads as an absent optional one.
void dwRejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> known,
  String what,
) {
  for (final key in json.keys) {
    if (!known.contains(key)) {
      throw FormatException('$what has an unknown key "$key"');
    }
  }
}

String _describe(Object? json) => switch (json) {
  null => 'null',
  Map() => 'an object',
  List() => 'an array',
  String() => 'a string',
  _ => '$json',
};
