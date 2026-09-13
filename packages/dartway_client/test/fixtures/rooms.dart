// DTOs in the exact shape `dartway generate` produces (see
// dartway_core/test/fixtures), written by hand so the client is exercised
// against the generated contract without the generator.

import 'package:dartway_client/dartway_client.dart';

enum AppChannel with DwChannelKind { rooms, room, notes }

final class RoomView extends DwDataObject with _$RoomView {
  const RoomView({required this.id, required this.name, this.rank = 0});

  @override
  final int id;
  final String name;
  final int rank;
}

mixin _$RoomView on DwDataObject {
  RoomView get _self => this as RoomView;
  @override
  String get dwTypeName => 'RoomView';
  @override
  Map<String, Object?> toJson() => {
    'id': _self.id,
    'name': _self.name,
    'rank': _self.rank,
  };
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomView &&
          other.id == _self.id &&
          other.name == _self.name &&
          other.rank == _self.rank;
  @override
  int get hashCode => Object.hash(_self.id, _self.name, _self.rank);
  @override
  String toString() => 'RoomView(${_self.id}, ${_self.name}, ${_self.rank})';
}

RoomView $RoomViewFromJson(Map<String, Object?> json) => RoomView(
  id: json['id']! as int,
  name: json['name']! as String,
  rank: json['rank']! as int,
);

/// A second data object type, travelling on the same channels.
final class NoteView extends DwDataObject with _$NoteView {
  const NoteView({required this.id, required this.text});

  @override
  final int id;
  final String text;
}

mixin _$NoteView on DwDataObject {
  NoteView get _self => this as NoteView;
  @override
  String get dwTypeName => 'NoteView';
  @override
  Map<String, Object?> toJson() => {'id': _self.id, 'text': _self.text};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteView && other.id == _self.id && other.text == _self.text;
  @override
  int get hashCode => Object.hash(_self.id, _self.text);
}

NoteView $NoteViewFromJson(Map<String, Object?> json) =>
    NoteView(id: json['id']! as int, text: json['text']! as String);

/// Every room; new rooms at the head.
final class ListRooms extends DwListRequest<RoomView> with _$ListRooms {
  const ListRooms({this.minRank});

  final int? minRank;

  @override
  List<DwChannel> get channels => const [DwChannel(AppChannel.rooms)];

  @override
  bool matches(RoomView object) => minRank == null || object.rank >= minRank!;
}

mixin _$ListRooms on DwListRequest<RoomView> {
  ListRooms get _self => this as ListRooms;
  @override
  String get dwTypeName => 'ListRooms';
  @override
  Map<String, Object?> toJson() => {
    if (_self.minRank != null) 'minRank': _self.minRank,
  };
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListRooms && other.minRank == _self.minRank;
  @override
  int get hashCode => Object.hash(ListRooms, _self.minRank);
}

ListRooms $ListRoomsFromJson(Map<String, Object?> json) =>
    ListRooms(minRank: json['minRank'] as int?);

/// Rooms ordered by rank; new rooms inserted by that order.
final class ListRoomsByRank extends DwListRequest<RoomView>
    with _$ListRoomsByRank {
  const ListRoomsByRank();

  @override
  List<DwChannel> get channels => const [DwChannel(AppChannel.rooms)];

  @override
  int Function(RoomView a, RoomView b)? get sort =>
      (a, b) => a.rank.compareTo(b.rank);
}

mixin _$ListRoomsByRank on DwListRequest<RoomView> {
  @override
  String get dwTypeName => 'ListRoomsByRank';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListRoomsByRank;
  @override
  int get hashCode => (ListRoomsByRank).hashCode;
}

ListRoomsByRank $ListRoomsByRankFromJson(Map<String, Object?> json) =>
    const ListRoomsByRank();

/// Notes: re-run whenever a room changes (derived data).
final class ListNotes extends DwListRequest<NoteView> with _$ListNotes {
  const ListNotes();

  @override
  List<DwChannel> get channels => const [
    DwChannel(AppChannel.rooms),
    DwChannel(AppChannel.notes),
  ];

  @override
  DwUpdate onUpdate(DwDto update) =>
      update is RoomView ? DwUpdate.refetch : DwUpdate.auto;
}

mixin _$ListNotes on DwListRequest<NoteView> {
  @override
  String get dwTypeName => 'ListNotes';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListNotes;
  @override
  int get hashCode => (ListNotes).hashCode;
}

ListNotes $ListNotesFromJson(Map<String, Object?> json) => const ListNotes();

final class GetRoom extends DwSingleRequest<RoomView> with _$GetRoom {
  const GetRoom(this.roomId);

  final int roomId;

  @override
  List<DwChannel> get channels => [DwChannel(AppChannel.room, roomId)];
}

mixin _$GetRoom on DwSingleRequest<RoomView> {
  GetRoom get _self => this as GetRoom;
  @override
  String get dwTypeName => 'GetRoom';
  @override
  Map<String, Object?> toJson() => {'roomId': _self.roomId};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetRoom && other.roomId == _self.roomId;
  @override
  int get hashCode => Object.hash(GetRoom, _self.roomId);
}

GetRoom $GetRoomFromJson(Map<String, Object?> json) =>
    GetRoom(json['roomId']! as int);

final class FindRoom extends DwMaybeRequest<RoomView> with _$FindRoom {
  const FindRoom(this.name);

  final String name;

  @override
  List<DwChannel> get channels => const [DwChannel(AppChannel.rooms)];

  @override
  bool matches(RoomView object) => object.name == name;
}

mixin _$FindRoom on DwMaybeRequest<RoomView> {
  FindRoom get _self => this as FindRoom;
  @override
  String get dwTypeName => 'FindRoom';
  @override
  Map<String, Object?> toJson() => {'name': _self.name};
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FindRoom && other.name == _self.name;
  @override
  int get hashCode => Object.hash(FindRoom, _self.name);
}

FindRoom $FindRoomFromJson(Map<String, Object?> json) =>
    FindRoom(json['name']! as String);

/// Offset pages of rooms ordered by rank.
final class FeedRooms extends DwPageRequest<RoomView> with _$FeedRooms {
  const FeedRooms({this.sorted = true});

  final bool sorted;

  @override
  int get pageSize => 2;

  @override
  List<DwChannel> get channels => const [DwChannel(AppChannel.rooms)];

  @override
  int Function(RoomView a, RoomView b)? get sort =>
      sorted ? (a, b) => a.rank.compareTo(b.rank) : null;
}

mixin _$FeedRooms on DwPageRequest<RoomView> {
  FeedRooms get _self => this as FeedRooms;
  @override
  String get dwTypeName => 'FeedRooms';
  @override
  Map<String, Object?> toJson() => {if (!_self.sorted) 'sorted': false};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedRooms && other.sorted == _self.sorted;
  @override
  int get hashCode => Object.hash(FeedRooms, _self.sorted);
}

FeedRooms $FeedRoomsFromJson(Map<String, Object?> json) =>
    FeedRooms(sorted: json['sorted'] as bool? ?? true);

/// Cursor pages of rooms, newest (highest id) first.
final class RoomHistory extends DwCursorRequest<RoomView> with _$RoomHistory {
  const RoomHistory();

  @override
  int get pageSize => 2;

  @override
  List<DwChannel> get channels => const [DwChannel(AppChannel.rooms)];
}

mixin _$RoomHistory on DwCursorRequest<RoomView> {
  @override
  String get dwTypeName => 'RoomHistory';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is RoomHistory;
  @override
  int get hashCode => (RoomHistory).hashCode;
}

RoomHistory $RoomHistoryFromJson(Map<String, Object?> json) =>
    const RoomHistory();

final class RenameRoom extends DwCommand<RoomView> with _$RenameRoom {
  const RenameRoom({required this.roomId, required this.name});

  final int roomId;
  final String name;
}

mixin _$RenameRoom on DwCommand<RoomView> {
  RenameRoom get _self => this as RenameRoom;
  @override
  String get dwTypeName => 'RenameRoom';
  @override
  Map<String, Object?> toJson() => {'roomId': _self.roomId, 'name': _self.name};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenameRoom &&
          other.roomId == _self.roomId &&
          other.name == _self.name;
  @override
  int get hashCode => Object.hash(RenameRoom, _self.roomId, _self.name);
}

RenameRoom $RenameRoomFromJson(Map<String, Object?> json) =>
    RenameRoom(roomId: json['roomId']! as int, name: json['name']! as String);

enum RoomRefusal with DwRefusalCodes { nameTaken }

final DwProtocol roomsProtocol = DwProtocol([
  DwDtoEntry(FeedRooms, 'FeedRooms', $FeedRoomsFromJson),
  DwDtoEntry(FindRoom, 'FindRoom', $FindRoomFromJson),
  DwDtoEntry(GetRoom, 'GetRoom', $GetRoomFromJson),
  DwDtoEntry(ListNotes, 'ListNotes', $ListNotesFromJson),
  DwDtoEntry(ListRooms, 'ListRooms', $ListRoomsFromJson),
  DwDtoEntry(ListRoomsByRank, 'ListRoomsByRank', $ListRoomsByRankFromJson),
  DwDtoEntry(NoteView, 'NoteView', $NoteViewFromJson),
  DwDtoEntry(RenameRoom, 'RenameRoom', $RenameRoomFromJson),
  DwDtoEntry(RoomHistory, 'RoomHistory', $RoomHistoryFromJson),
  DwDtoEntry(RoomView, 'RoomView', $RoomViewFromJson),
], include: DwProtocol.core);

const rooms = DwChannel(AppChannel.rooms);
const notes = DwChannel(AppChannel.notes);
