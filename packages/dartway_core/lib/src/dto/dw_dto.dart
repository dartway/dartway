import '../protocol/dw_protocol.dart';

/// Anything that travels between a DartWay server and its clients.
///
/// A project never extends this directly: it extends one of the three kinds —
/// [DwDataObject], `DwRequest` or `DwCommand`. The members below are supplied by
/// the generated `_$Name` mixin of each class (`dartway generate`); nobody writes
/// them by hand.
abstract class DwDto {
  const DwDto();

  /// The name this class travels under. Unique across the protocol.
  String get dwTypeName;

  /// The fields of this DTO as JSON. Absent optional fields are omitted — the
  /// wire carries nothing the receiver can do without.
  Map<String, Object?> toJson();
}

/// Data the server returns and publishes: the unit of client state.
///
/// Every data object has an identity. Updates arriving on a channel are merged
/// into the state of a request by [id], which is why an object without one
/// cannot be a data object — wrap such data in a single-object request result.
abstract class DwDataObject extends DwDto {
  const DwDataObject();

  /// The identity updates are merged by. An `int` or a `String`.
  Object get id;
}

/// An update saying that the data object of [typeName] with [id] is gone.
final class DwDeleted extends DwDto {
  const DwDeleted({required this.typeName, required this.id});

  /// Builds the deletion notice for a data object type.
  static DwDeleted of<T extends DwDataObject>(Object id, DwProtocol protocol) =>
      DwDeleted(typeName: protocol.nameOf(T), id: id);

  final String typeName;
  final Object id;

  /// Whether this deletion concerns a data object of type [T].
  bool isOf<T extends DwDataObject>(DwProtocol protocol) =>
      protocol.nameOf(T) == typeName;

  @override
  String get dwTypeName => 'DwDeleted';

  @override
  Map<String, Object?> toJson() => {'type': typeName, 'id': id};

  static DwDeleted fromJson(Map<String, Object?> json) =>
      DwDeleted(typeName: json['type']! as String, id: json['id']!);

  @override
  bool operator ==(Object other) =>
      other is DwDeleted && other.typeName == typeName && other.id == id;

  @override
  int get hashCode => Object.hash(typeName, id);

  @override
  String toString() => 'DwDeleted($typeName#$id)';
}
