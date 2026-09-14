import '../wire/dw_wire_object.dart';
import 'dw_wire_protocol.dart';
import 'dw_read.dart';

/// What was published to one channel, as it travels: data objects and
/// [DwDeletedObject] notices grouped by wire name.
///
/// ```json
/// {"ClubSession": [{"id": 3, …}, {"id": 4, …}], "DwDeletedObject": [{"type": "Booking", "id": 9}]}
/// ```
///
/// The body of a live `upd` message, which names its channel beside it, and
/// one channel's part of a [DwUpdateTransport].
///
/// **The only place a type name stands next to objects.** A call's body is
/// typed by its path and its result by its call; only updates mix types, and
/// a group names its type once instead of tagging every object.
///
/// An object is here at most once: the key is the type and the id, where a
/// deletion's type is the type it deletes. A later object replaces an earlier
/// one with the same key — a row updated twice travels once, as it ended, and
/// a row updated then deleted travels as its deletion. That is also what makes
/// the grouping safe: with every key once, the order between groups cannot
/// change the outcome, and within a group the order is kept.
final class DwChannelUpdates {
  /// Collects [objects] in order: duplicates by key collapse to the last one,
  /// which keeps the position of that last occurrence. Throws [ArgumentError]
  /// for an object that is neither a [DwDataObject] nor a [DwDeletedObject].
  factory DwChannelUpdates(Iterable<DwWireObject> objects) {
    final list = objects.toList();
    final latest = <(String, Object), int>{};
    for (var i = 0; i < list.length; i++) {
      latest[_keyOf(list[i])] = i;
    }
    if (list.isEmpty) return empty;
    final groups = <String, List<DwWireObject>>{};
    for (var i = 0; i < list.length; i++) {
      final object = list[i];
      if (latest[_keyOf(object)] != i) continue;
      (groups[object.dwTypeName] ??= []).add(object);
    }
    return DwChannelUpdates._(
      List.unmodifiable([for (final group in groups.values) ...group]),
    );
  }

  const DwChannelUpdates._(this.objects);

  /// Nothing published.
  static const DwChannelUpdates empty = DwChannelUpdates._([]);

  /// Decodes the groups produced by [toJson]. Throws [FormatException] for an
  /// unknown group name, a group of a type that is not a data object or
  /// [DwDeletedObject], an empty group, a deletion of a type that is not a data
  /// object, or an object that appears twice.
  factory DwChannelUpdates.fromJson(Object? json, DwWireProtocol protocol) {
    const what = 'The updates of a channel';
    final groups = dwReadMap(json, what);
    final objects = <DwWireObject>[];
    final keys = <(String, Object)>{};
    for (final MapEntry(key: name, value: items) in groups.entries) {
      final entry = protocol.entryNamed(name);
      if (entry == null) {
        throw FormatException('$what have a group of unknown type "$name"');
      }
      if (entry.kind != DwWireObjectKind.dataObject &&
          entry.type != DwDeletedObject) {
        throw FormatException(
          '$what carry data objects and deletions; "$name" is neither',
        );
      }
      final group = dwReadList(items, 'The group "$name"');
      if (group.isEmpty) {
        throw FormatException('$what have an empty group "$name"');
      }
      for (final item in group) {
        final object = entry.fromJson(dwReadMap(item, 'An object of "$name"'));
        if (object is DwDeletedObject &&
            protocol.entryNamed(object.typeName)?.kind !=
                DwWireObjectKind.dataObject) {
          throw FormatException(
            '$what delete a "${object.typeName}", which is not a data object '
            'of this protocol',
          );
        }
        if (!keys.add(_keyOf(object))) {
          throw FormatException(
            '$what carry ${_describe(object)} twice; objects are collapsed '
            'before sending',
          );
        }
        objects.add(object);
      }
    }
    return objects.isEmpty
        ? empty
        : DwChannelUpdates._(List.unmodifiable(objects));
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
      'updates carry data objects and deletions, not ${object.dwTypeName}',
    ),
  };

  static String _describe(DwWireObject object) => switch (object) {
    DwDeletedObject() => object.toString(),
    DwDataObject(:final id) => '${object.dwTypeName}#$id',
    _ => object.dwTypeName,
  };

  @override
  bool operator ==(Object other) {
    if (other is! DwChannelUpdates || other.objects.length != objects.length) {
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
  String toString() => 'DwChannelUpdates(${objects.map(_describe).join(', ')})';
}

/// The updates a call's response carries: what the call published, grouped by
/// the wire name of the channel it was published to, then by type.
///
/// ```json
/// {"bookings:7": {"SessionBooking": [{…}]}, "schedule": {"ClubSession": [{…}]}}
/// ```
///
/// **Every object travels with its channel (D-036)**, because the channel is
/// the only fact that says whose data an object is. An admin changing a
/// member's role publishes that member's profile to `profile:<member>`; a
/// client routing by type alone would put it into the admin's own "my
/// profile". The client applies an object only to the requests that declare
/// the channel it came on.
///
/// Within a channel an object travels once, as it ended ([DwChannelUpdates]).
/// The same object published to two channels travels under both: each reaches
/// other requests.
final class DwUpdateTransport {
  /// Collects [publications] — `(channel wire name, object)`, in the order
  /// they were published — channel by channel, each collapsed as
  /// [DwChannelUpdates] collapses. Throws [ArgumentError] for an empty channel
  /// name or an object that is neither a [DwDataObject] nor a
  /// [DwDeletedObject].
  factory DwUpdateTransport(
    Iterable<(String channel, DwWireObject object)> publications,
  ) {
    final byChannel = <String, List<DwWireObject>>{};
    for (final (channel, object) in publications) {
      if (channel.isEmpty) {
        throw ArgumentError.value(channel, 'channel', 'must not be empty');
      }
      (byChannel[channel] ??= []).add(object);
    }
    if (byChannel.isEmpty) return empty;
    return DwUpdateTransport._(
      Map.unmodifiable({
        for (final MapEntry(key: channel, value: objects) in byChannel.entries)
          channel: DwChannelUpdates(objects),
      }),
    );
  }

  const DwUpdateTransport._(this.channels);

  /// A transport without objects.
  static const DwUpdateTransport empty = DwUpdateTransport._({});

  /// Decodes a transport produced by [toJson]. Throws [FormatException] for
  /// an empty channel name, a channel without objects, or a channel whose
  /// groups do not decode ([DwChannelUpdates.fromJson]).
  factory DwUpdateTransport.fromJson(Object? json, DwWireProtocol protocol) {
    const what = 'A transport';
    final map = dwReadMap(json, what);
    final channels = <String, DwChannelUpdates>{};
    for (final MapEntry(key: channel, value: groups) in map.entries) {
      if (channel.isEmpty) {
        throw const FormatException('$what has a channel without a name');
      }
      final updates = DwChannelUpdates.fromJson(groups, protocol);
      if (updates.isEmpty) {
        throw FormatException('$what has no objects for channel "$channel"');
      }
      channels[channel] = updates;
    }
    return channels.isEmpty
        ? empty
        : DwUpdateTransport._(Map.unmodifiable(channels));
  }

  /// The updates of each channel by wire name, in the order the channels were
  /// first published to. No channel is present without objects.
  final Map<String, DwChannelUpdates> channels;

  bool get isEmpty => channels.isEmpty;

  bool get isNotEmpty => channels.isNotEmpty;

  /// The objects published to [channel], a wire name; empty when none.
  List<DwWireObject> objectsOn(String channel) =>
      channels[channel]?.objects ?? const [];

  /// `{channel: {name: [json…]}}`; `{}` when empty.
  Map<String, Object?> toJson() => {
    for (final MapEntry(key: channel, value: updates) in channels.entries)
      channel: updates.toJson(),
  };

  /// Equal when every channel carries equal updates. The order between
  /// channels is not compared: each channel reaches its own requests.
  @override
  bool operator ==(Object other) {
    if (other is! DwUpdateTransport ||
        other.channels.length != channels.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in channels.entries) {
      if (other.channels[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final MapEntry(:key, :value) in channels.entries)
      Object.hash(key, value),
  ]);

  @override
  String toString() {
    final channels = [
      for (final MapEntry(:key, :value) in this.channels.entries)
        '$key: ${value.objects.map(DwChannelUpdates._describe).join(', ')}',
    ];
    return 'DwUpdateTransport(${channels.join('; ')})';
  }
}
