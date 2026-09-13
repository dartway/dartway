import '../auth/dw_auth_dtos.dart';
import '../dto/dw_dto.dart';

/// Builds a DTO from its JSON fields.
typedef DwDtoFactory = DwDto Function(Map<String, Object?> json);

/// One registered DTO class: its wire name and its factory.
final class DwDtoEntry {
  const DwDtoEntry(this.type, this.name, this.fromJson);

  final Type type;
  final String name;
  final DwDtoFactory fromJson;
}

/// The set of DTO classes a server and its clients agree on.
///
/// The project's registry is generated into its shared package
/// (`lib/generated/dw_protocol.dart`) and composed with [DwProtocol.core], which
/// holds the framework's own DTOs. Both sides of the wire use the same instance.
final class DwProtocol {
  DwProtocol(Iterable<DwDtoEntry> entries, {DwProtocol? include}) {
    if (include != null) {
      for (final entry in include._byName.values) {
        _add(entry);
      }
    }
    for (final entry in entries) {
      _add(entry);
    }
  }

  final Map<String, DwDtoEntry> _byName = {};
  final Map<Type, DwDtoEntry> _byType = {};

  void _add(DwDtoEntry entry) {
    final existing = _byName[entry.name];
    if (existing != null && existing.type != entry.type) {
      throw StateError(
        'Two DTO classes travel under the name "${entry.name}": '
        '${existing.type} and ${entry.type}. Wire names must be unique.',
      );
    }
    _byName[entry.name] = entry;
    _byType[entry.type] = entry;
  }

  /// The framework's own DTOs, present in every protocol.
  static final DwProtocol core = DwProtocol([
    DwDtoEntry(DwDeleted, 'DwDeleted', DwDeleted.fromJson),
    ...dwAuthDtoEntries,
  ]);

  /// Whether [type] is registered.
  bool knows(Type type) => _byType.containsKey(type);

  /// The wire name of a registered DTO type.
  String nameOf(Type type) {
    final entry = _byType[type];
    if (entry == null) {
      throw StateError('$type is not registered in this protocol.');
    }
    return entry.name;
  }

  /// Encodes [dto] with its type tag, for places where the receiver cannot know
  /// the type statically (updates, command results).
  Map<String, Object?> encodeTagged(DwDto dto) => {
    '@t': dto.dwTypeName,
    ...dto.toJson(),
  };

  /// Decodes a tagged DTO produced by [encodeTagged].
  DwDto decodeTagged(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('A tagged DTO must be a JSON object, got $json');
    }
    final name = json['@t'];
    final entry = _byName[name];
    if (entry == null) {
      throw FormatException('Unknown DTO type "$name"');
    }
    return entry.fromJson(json);
  }

  /// Decodes an untagged DTO whose type the receiver knows statically.
  T decodeAs<T extends DwDto>(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('A $T must be a JSON object, got $json');
    }
    final entry = _byType[T];
    if (entry == null) {
      throw StateError('$T is not registered in this protocol.');
    }
    return entry.fromJson(json) as T;
  }

  /// Encodes a single value of unknown static shape: null, a JSON primitive or
  /// a DTO (tagged). Used for command results.
  Object? encodeValue(Object? value) => switch (value) {
    null => null,
    DwDto() => encodeTagged(value),
    num() || String() || bool() => value,
    _ => throw ArgumentError(
      'A command result must be null, a JSON primitive or a DTO; '
      'got ${value.runtimeType}. Wrap collections in a DTO.',
    ),
  };

  /// Decodes a value produced by [encodeValue].
  Object? decodeValue(Object? json) =>
      json is Map<String, Object?> ? decodeTagged(json) : json;
}
