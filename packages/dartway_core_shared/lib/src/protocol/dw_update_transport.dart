import '../wire/dw_wire_object.dart';
import 'dw_wire_protocol.dart';
import 'dw_read.dart';

/// The updates one command produced, as they travel: data objects and
/// [DwDeletedObject] notices grouped by wire name.
///
/// ```json
/// {"ClubSession": [{"id": 3, …}, {"id": 4, …}], "DwDeletedObject": [{"type": "Booking", "id": 9}]}
/// ```
///
/// **The only place a type name stands next to objects.** A call's body is
/// typed by its path and its result by its call; only updates mix types, and
/// a group names its type once instead of tagging every object.
///
/// An object is in a transport at most once: the key is the type and the id,
/// where a deletion's type is the type it deletes. A later object replaces an
/// earlier one with the same key — a row updated twice travels once, as it
/// ended, and a row updated then deleted travels as its deletion. That is
/// also what makes the grouping safe: with every key once, the order between
/// groups cannot change the outcome, and within a group the order is kept.
final class DwUpdateTransport {
  /// Collects [objects] in order: duplicates by key collapse to the last one,
  /// which keeps the position of that last occurrence. Throws [ArgumentError]
  /// for an object that is neither a [DwDataObject] nor a [DwDeletedObject].
  factory DwUpdateTransport(Iterable<DwWireObject> objects) {
    final latest = <(String, Object), int>{};
    final list = objects.toList();
    for (var i = 0; i < list.length; i++) {
      latest[_keyOf(list[i])] = i;
    }
    final groups = <String, List<DwWireObject>>{};
    for (var i = 0; i < list.length; i++) {
      final object = list[i];
      if (latest[_keyOf(object)] != i) continue;
      (groups[object.dwTypeName] ??= []).add(object);
    }
    return DwUpdateTransport._(
      List.unmodifiable([for (final group in groups.values) ...group]),
    );
  }

  const DwUpdateTransport._(this.objects);

  /// A transport without objects.
  static const DwUpdateTransport empty = DwUpdateTransport._([]);

  /// Decodes a transport produced by [toJson]. Throws [FormatException] for
  /// an unknown group name, a group of a type that is not a data object or
  /// [DwDeletedObject], an empty group, a deletion of a type that is not a data
  /// object, or an object that appears twice.
  factory DwUpdateTransport.fromJson(Object? json, DwWireProtocol protocol) {
    const what = 'A transport';
    final groups = dwReadMap(json, what);
    final objects = <DwWireObject>[];
    final keys = <(String, Object)>{};
    for (final MapEntry(key: name, value: items) in groups.entries) {
      final entry = protocol.entryNamed(name);
      if (entry == null) {
        throw FormatException('$what has a group of unknown type "$name"');
      }
      if (entry.kind != DwWireObjectKind.dataObject &&
          entry.type != DwDeletedObject) {
        throw FormatException(
          '$what carries data objects and deletions; "$name" is neither',
        );
      }
      final group = dwReadList(items, 'The group "$name"');
      if (group.isEmpty) {
        throw FormatException('$what has an empty group "$name"');
      }
      for (final item in group) {
        final object = entry.fromJson(dwReadMap(item, 'An object of "$name"'));
        if (object is DwDeletedObject &&
            protocol.entryNamed(object.typeName)?.kind !=
                DwWireObjectKind.dataObject) {
          throw FormatException(
            '$what deletes a "${object.typeName}", which is not a data object '
            'of this protocol',
          );
        }
        if (!keys.add(_keyOf(object))) {
          throw FormatException(
            '$what carries ${_describe(object)} twice; objects are collapsed '
            'before sending',
          );
        }
        objects.add(object);
      }
    }
    return DwUpdateTransport._(List.unmodifiable(objects));
  }

  /// Every object, group by group, in order within a group.
  final List<DwWireObject> objects;

  bool get isEmpty => objects.isEmpty;

  bool get isNotEmpty => objects.isNotEmpty;

  /// `{name: [json…]}`; `{}` when empty.
  Map<String, Object?> toJson() {
    final groups = <String, List<Map<String, Object?>>>{};
    for (final object in objects) {
      (groups[object.dwTypeName] ??= []).add(object.toJson());
    }
    return groups;
  }

  static (String, Object) _keyOf(DwWireObject object) => switch (object) {
    DwDeletedObject(:final typeName, :final id) => (typeName, id),
    DwDataObject(:final id) => (object.dwTypeName, id),
    _ => throw ArgumentError.value(
      object,
      'objects',
      'a transport carries data objects and deletions, not '
          '${object.dwTypeName}',
    ),
  };

  static String _describe(DwWireObject object) => switch (object) {
    DwDeletedObject() => object.toString(),
    DwDataObject(:final id) => '${object.dwTypeName}#$id',
    _ => object.dwTypeName,
  };

  @override
  bool operator ==(Object other) {
    if (other is! DwUpdateTransport || other.objects.length != objects.length) {
      return false;
    }
    for (var i = 0; i < objects.length; i++) {
      if (other.objects[i] != objects[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(objects);

  @override
  String toString() =>
      'DwUpdateTransport(${objects.map(_describe).join(', ')})';
}
