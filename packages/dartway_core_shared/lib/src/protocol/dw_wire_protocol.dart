import '../auth/dw_auth_wire_objects.dart';
import '../files/dw_file_wire_objects.dart';
import '../wire/dw_server_call.dart';
import '../wire/dw_wire_object.dart';
import 'dw_http_contract.dart';

/// Builds a DTO of type [T] from its JSON fields.
typedef DwWireObjectFactory<T extends DwWireObject> =
    T Function(Map<String, Object?> json);

/// Which of the DTO kinds a registered class is.
enum DwWireObjectKind {
  /// A `DwDataObject`.
  dataObject,

  /// A `DwDataRequest` of any request kind.
  request,

  /// A `DwActionCommand`.
  command,

  /// Anything else that travels — `DwDeletedObject`, a nested value DTO.
  other,
}

/// One registered DTO class: its wire name and its factory, typed by the class.
///
/// **The type argument is the class** and must be written out, as the
/// generated registry does:
///
/// ```dart
/// DwProtocolEntry<SessionBooking>('SessionBooking', $SessionBookingFromJson)
/// ```
///
/// Inside a list literal Dart infers it from the list's element type
/// (`DwWireObject`), not from the factory, so an entry without it would
/// register `DwWireObject` itself; [DwWireProtocol] refuses such an entry.
///
/// Because the entry is typed, the questions only a type can answer — which
/// kind the class is, whether it is a command's result type — are asked of
/// the entry, never probed from a `Type` object, which cannot be asked about
/// subtyping.
final class DwProtocolEntry<T extends DwWireObject> {
  const DwProtocolEntry(this.name, this.fromJson);

  /// The name the class travels under: the call path (`/dw/<name>`) and the
  /// group name in a transport.
  final String name;

  /// The class's own factory — `$NameFromJson`, or a static `fromJson`.
  final DwWireObjectFactory<T> fromJson;

  /// The registered class.
  Type get type => T;

  DwWireObjectKind get kind {
    final list = <T>[];
    if (list is List<DwDataRequest<Object?>>) return DwWireObjectKind.request;
    if (list is List<DwActionCommand<Object?>>) return DwWireObjectKind.command;
    if (list is List<DwDataObject>) return DwWireObjectKind.dataObject;
    return DwWireObjectKind.other;
  }

  /// Whether [R] is this class or its nullable form — the one question a
  /// command's result type puts to the registry.
  bool _isTypeOrNullable<R>() => <T>[] is List<R> && <R>[] is List<T?>;

  /// Whether [T] is one of the framework's abstract bases — what an entry
  /// whose type argument was inferred rather than written ends up with.
  bool get _isFrameworkBase =>
      <DwDataObject>[] is List<T> ||
      <DwServerCall<Never>>[] is List<T> ||
      <DwDataRequest<Never>>[] is List<T> ||
      <DwActionCommand<Never>>[] is List<T>;

  @override
  String toString() => 'DwProtocolEntry<$T>($name, ${kind.name})';
}

/// The set of DTO classes a server and its clients agree on.
///
/// The project's registry is generated into its shared package
/// (`lib/generated/dw_protocol.dart`) and composed with [DwWireProtocol.core],
/// which holds the framework's own DTOs. Both sides of the wire use the same
/// instance.
///
/// Nothing on the wire carries a type tag: a call's body is typed by its path,
/// a result by its call, and objects in a `DwUpdateTransport` by their group
/// name.
final class DwWireProtocol {
  /// Throws [ArgumentError] for an entry whose type argument is a framework
  /// base or whose name cannot be a call path, and [StateError] for two
  /// classes under one name or one class under two names.
  DwWireProtocol(Iterable<DwProtocolEntry> entries, {DwWireProtocol? include}) {
    if (include != null) {
      for (final entry in include._byName.values) {
        _add(entry);
      }
    }
    for (final entry in entries) {
      _add(entry);
    }
  }

  final Map<String, DwProtocolEntry> _byName = {};
  final Map<Type, DwProtocolEntry> _byType = {};

  /// Result types already looked up by [decodeValue]; `null` for a type that
  /// is not a registered DTO.
  final Map<Type, DwProtocolEntry?> _resultEntries = {};

  /// A wire name is a call path segment: an identifier, nothing a URL would
  /// need to escape.
  static final _namePattern = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  void _add(DwProtocolEntry entry) {
    if (entry._isFrameworkBase) {
      throw ArgumentError(
        'The DTO entry "${entry.name}" registers ${entry.type}, a framework '
        'base, not a class: write the type argument out, '
        'DwProtocolEntry<${entry.name}>(...).',
      );
    }
    if (!_namePattern.hasMatch(entry.name) ||
        entry.name == DwHttpContract.liveSegment) {
      throw ArgumentError(
        'The DTO name "${entry.name}" cannot be a call path: it must be an '
        'identifier other than "${DwHttpContract.liveSegment}".',
      );
    }
    final existing = _byName[entry.name];
    if (existing != null && existing.type != entry.type) {
      throw StateError(
        'Two DTO classes travel under the name "${entry.name}": '
        '${existing.type} and ${entry.type}. Wire names must be unique.',
      );
    }
    final sameType = _byType[entry.type];
    if (sameType != null && sameType.name != entry.name) {
      throw StateError(
        '${entry.type} is registered under two names: "${sameType.name}" and '
        '"${entry.name}".',
      );
    }
    _byName[entry.name] = entry;
    _byType[entry.type] = entry;
  }

  /// The framework's own DTOs, present in every protocol.
  static final DwWireProtocol core = DwWireProtocol([
    const DwProtocolEntry<DwDeletedObject>(
      'DwDeletedObject',
      DwDeletedObject.fromJson,
    ),
    ...dwAuthProtocolEntries,
    ...dwFileProtocolEntries,
  ]);

  /// Every registered class, the included protocol's first, each once.
  Iterable<DwProtocolEntry> get entries => _byName.values;

  /// Whether [type] is registered.
  bool knows(Type type) => _byType.containsKey(type);

  /// The entry registered under [name], or `null` — for the server, an
  /// unknown call path.
  DwProtocolEntry? entryNamed(String name) => _byName[name];

  /// The wire name of a registered DTO type.
  String nameOf(Type type) {
    final entry = _byType[type];
    if (entry == null) {
      throw StateError('$type is not registered in this protocol.');
    }
    return entry.name;
  }

  /// Decodes the JSON of the class registered under [name]. Throws
  /// [FormatException] for an unknown name or a [json] that is not an object.
  DwWireObject decodeNamed(String name, Object? json) {
    final entry = _byName[name];
    if (entry == null) throw FormatException('Unknown DTO type "$name"');
    if (json is! Map<String, Object?>) {
      throw FormatException('A $name must be a JSON object, got $json');
    }
    return entry.fromJson(json);
  }

  /// Decodes a DTO whose type the receiver knows statically. Throws
  /// [StateError] when [T] is not registered and [FormatException] when
  /// [json] is not an object.
  T decodeAs<T extends DwWireObject>(Object? json) {
    final entry = _byType[T];
    if (entry == null) {
      throw StateError('$T is not registered in this protocol.');
    }
    if (json is! Map<String, Object?>) {
      throw FormatException('A $T must be a JSON object, got $json');
    }
    return entry.fromJson(json) as T;
  }

  /// Encodes a command result: `null`, a JSON primitive, or a DTO (its own
  /// JSON, untagged). Throws [ArgumentError] for anything else.
  Object? encodeValue(Object? value) => switch (value) {
    null => null,
    DwWireObject() => value.toJson(),
    num() || String() || bool() => value,
    _ => throw ArgumentError(
      'A command result must be null, a JSON primitive or a DTO; '
      'got ${value.runtimeType}. Wrap collections in a DTO.',
    ),
  };

  /// Decodes a command result of type [R] produced by [encodeValue].
  ///
  /// [R] says what the JSON is: `null` is accepted only by a nullable [R] (and
  /// `void`); an object only by a registered DTO class or its nullable form; a
  /// primitive only by an [R] it is — a JSON integer is read as a `double`
  /// when [R] is one. Anything else throws [FormatException]; a DTO type [R]
  /// that is not registered throws [StateError].
  R decodeValue<R>(Object? json) {
    if (json == null) {
      if (<Null>[] is List<R>) return null as R;
      throw FormatException('A result of type $R cannot be null');
    }
    if (json is Map<String, Object?>) {
      final entry = _resultEntries.putIfAbsent(
        R,
        () => _byName.values
            .where((entry) => entry._isTypeOrNullable<R>())
            .firstOrNull,
      );
      if (entry != null) return entry.fromJson(json) as R;
      if (<R>[] is List<DwWireObject?>) {
        throw StateError(
          'The result type $R is not a DTO registered in this protocol.',
        );
      }
      throw FormatException('A result of type $R cannot be a JSON object');
    }
    if (json is R) return json as R;
    // On the VM a JSON number without a fraction decodes as an `int`.
    if (json is int && <double>[] is List<R>) return json.toDouble() as R;
    throw FormatException(
      'A result of type $R cannot be ${json.runtimeType} $json',
    );
  }
}
