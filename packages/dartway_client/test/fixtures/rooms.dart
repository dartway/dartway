// DTOs in the exact shape `dartway generate` produces (see
// dartway_core_shared/test/fixtures), written by hand so the client is exercised
// against the generated contract without the generator.

import 'package:dartway_client/dartway_client.dart';

enum AppChannel with DwChannelKind { rooms, room, notes, chat }

const roomsChannel = DwLiveChannel(AppChannel.rooms);
const notesChannel = DwLiveChannel(AppChannel.notes);
const chatChannel = DwLiveChannel(AppChannel.chat);

// --- data objects ------------------------------------------------------------

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
  @override
  String toString() => 'NoteView(${_self.id}, ${_self.text})';
}

NoteView $NoteViewFromJson(Map<String, Object?> json) =>
    NoteView(id: json['id']! as int, text: json['text']! as String);

/// A chat line: sorted by [at], then id, newest first.
final class ChatLine extends DwDataObject with _$ChatLine {
  const ChatLine({required this.id, required this.at, required this.text});

  @override
  final int id;
  final int at;
  final String text;
}

mixin _$ChatLine on DwDataObject {
  ChatLine get _self => this as ChatLine;
  @override
  String get dwTypeName => 'ChatLine';
  @override
  Map<String, Object?> toJson() => {
    'id': _self.id,
    'at': _self.at,
    'text': _self.text,
  };
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatLine &&
          other.id == _self.id &&
          other.at == _self.at &&
          other.text == _self.text;
  @override
  int get hashCode => Object.hash(_self.id, _self.at, _self.text);
  @override
  String toString() => 'ChatLine(${_self.id}, ${_self.text})';
}

ChatLine $ChatLineFromJson(Map<String, Object?> json) => ChatLine(
  id: json['id']! as int,
  at: json['at']! as int,
  text: json['text']! as String,
);

// --- requests ----------------------------------------------------------------

/// Every room; new rooms at the head.
final class ListRooms extends DwListRequest<RoomView>
    with _$ListRooms
    implements DwSelfValidating {
  const ListRooms({this.minRank});

  final int? minRank;

  @override
  List<DwCallRefusal> validate() => [
    if (minRank != null && minRank! < 0)
      DwCallRefusal(
        DwCoreRefusal.invalid,
        field: 'minRank',
        params: {'min': 0},
      ),
  ];

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];

  @override
  bool matches(RoomView item) => minRank == null || item.rank >= minRank!;
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
  List<DwLiveChannel> get channels => const [roomsChannel];

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

/// Rooms without channels: fresh as its last fetch, and still updated by the
/// transport of a response.
final class ListRoomsOffline extends DwListRequest<RoomView>
    with _$ListRoomsOffline {
  const ListRoomsOffline();
}

mixin _$ListRoomsOffline on DwListRequest<RoomView> {
  @override
  String get dwTypeName => 'ListRoomsOffline';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListRoomsOffline;
  @override
  int get hashCode => (ListRoomsOffline).hashCode;
}

ListRoomsOffline $ListRoomsOfflineFromJson(Map<String, Object?> json) =>
    const ListRoomsOffline();

/// Rooms whose membership only the server decides.
final class ListPinnedRooms extends DwListRequest<RoomView>
    with _$ListPinnedRooms {
  const ListPinnedRooms() : super.updateOnly();

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];
}

mixin _$ListPinnedRooms on DwListRequest<RoomView> {
  @override
  String get dwTypeName => 'ListPinnedRooms';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListPinnedRooms;
  @override
  int get hashCode => (ListPinnedRooms).hashCode;
}

ListPinnedRooms $ListPinnedRoomsFromJson(Map<String, Object?> json) =>
    const ListPinnedRooms();

/// Derived data: every room update re-runs it.
final class ListRoomStats extends DwListRequest<RoomView> with _$ListRoomStats {
  const ListRoomStats() : super.refetchOnUpdate();

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];
}

mixin _$ListRoomStats on DwListRequest<RoomView> {
  @override
  String get dwTypeName => 'ListRoomStats';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListRoomStats;
  @override
  int get hashCode => (ListRoomStats).hashCode;
}

ListRoomStats $ListRoomStatsFromJson(Map<String, Object?> json) =>
    const ListRoomStats();

/// The caller's own notes: "my" data, no account id in the request.
final class ListMyNotes extends DwListRequest<NoteView> with _$ListMyNotes {
  const ListMyNotes();

  @override
  List<DwLiveChannel> get channels => const [notesChannel];
}

mixin _$ListMyNotes on DwListRequest<NoteView> {
  @override
  String get dwTypeName => 'ListMyNotes';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListMyNotes;
  @override
  int get hashCode => (ListMyNotes).hashCode;
}

ListMyNotes $ListMyNotesFromJson(Map<String, Object?> json) =>
    const ListMyNotes();

final class GetRoom extends DwSingleRequest<RoomView> with _$GetRoom {
  const GetRoom(this.roomId);

  final int roomId;

  @override
  List<DwLiveChannel> get channels => [DwLiveChannel(AppChannel.room, roomId)];
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
  List<DwLiveChannel> get channels => const [roomsChannel];

  @override
  bool matches(RoomView item) => item.name == name;
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

/// Offset pages of rooms, two per page, ordered by rank (or unsorted).
final class FeedRooms extends DwPageRequest<RoomView> with _$FeedRooms {
  const FeedRooms({this.sorted = true}) : super(pageSize: 2, maxPageSize: 3);

  final bool sorted;

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];

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

/// Numbered pages of rooms.
final class RoomsTable extends DwTableRequest<RoomView> with _$RoomsTable {
  const RoomsTable({this.page = 1, this.pageSize = 2}) : super(maxPageSize: 10);

  @override
  final int page;
  @override
  final int pageSize;

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];
}

mixin _$RoomsTable on DwTableRequest<RoomView> {
  RoomsTable get _self => this as RoomsTable;
  @override
  String get dwTypeName => 'RoomsTable';
  @override
  Map<String, Object?> toJson() => {
    'page': _self.page,
    'pageSize': _self.pageSize,
  };
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomsTable &&
          other.page == _self.page &&
          other.pageSize == _self.pageSize;
  @override
  int get hashCode => Object.hash(RoomsTable, _self.page, _self.pageSize);
}

RoomsTable $RoomsTableFromJson(Map<String, Object?> json) =>
    RoomsTable(page: json['page']! as int, pageSize: json['pageSize']! as int);

/// The chat, read as a window: three lines per load.
final class ReadChat extends DwWindowRequest<ChatLine, int, int>
    with _$ReadChat {
  const ReadChat() : super(pageSize: 3, maxPageSize: 20);

  @override
  DwWindowPosition<int, int> positionOf(ChatLine item) =>
      (sortValue: item.at, id: item.id);

  @override
  List<DwLiveChannel> get channels => const [chatChannel];
}

mixin _$ReadChat on DwWindowRequest<ChatLine, int, int> {
  @override
  String get dwTypeName => 'ReadChat';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ReadChat;
  @override
  int get hashCode => (ReadChat).hashCode;
}

ReadChat $ReadChatFromJson(Map<String, Object?> json) => const ReadChat();

// --- commands ----------------------------------------------------------------

final class RenameRoom extends DwActionCommand<RoomView>
    with _$RenameRoom
    implements DwSelfValidating {
  const RenameRoom({required this.roomId, required this.name});

  final int roomId;
  final String name;

  @override
  List<DwCallRefusal> validate() => [
    if (name.isEmpty) DwCallRefusal(DwCoreRefusal.invalid, field: 'name'),
  ];
}

mixin _$RenameRoom on DwActionCommand<RoomView> {
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

final class DeleteRoom extends DwActionCommand<void> with _$DeleteRoom {
  const DeleteRoom(this.roomId);

  final int roomId;
}

mixin _$DeleteRoom on DwActionCommand<void> {
  DeleteRoom get _self => this as DeleteRoom;
  @override
  String get dwTypeName => 'DeleteRoom';
  @override
  Map<String, Object?> toJson() => {'roomId': _self.roomId};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeleteRoom && other.roomId == _self.roomId;
  @override
  int get hashCode => Object.hash(DeleteRoom, _self.roomId);
}

DeleteRoom $DeleteRoomFromJson(Map<String, Object?> json) =>
    DeleteRoom(json['roomId']! as int);

enum RoomRefusal with DwRefusalCodes { nameTaken }

final DwWireProtocol roomsProtocol = DwWireProtocol([
  const DwProtocolEntry<ChatLine>('ChatLine', $ChatLineFromJson),
  const DwProtocolEntry<DeleteRoom>('DeleteRoom', $DeleteRoomFromJson),
  const DwProtocolEntry<FeedRooms>('FeedRooms', $FeedRoomsFromJson),
  const DwProtocolEntry<FindRoom>('FindRoom', $FindRoomFromJson),
  const DwProtocolEntry<GetRoom>('GetRoom', $GetRoomFromJson),
  const DwProtocolEntry<ListMyNotes>('ListMyNotes', $ListMyNotesFromJson),
  const DwProtocolEntry<ListPinnedRooms>(
    'ListPinnedRooms',
    $ListPinnedRoomsFromJson,
  ),
  const DwProtocolEntry<ListRoomStats>('ListRoomStats', $ListRoomStatsFromJson),
  const DwProtocolEntry<ListRooms>('ListRooms', $ListRoomsFromJson),
  const DwProtocolEntry<ListRoomsByRank>(
    'ListRoomsByRank',
    $ListRoomsByRankFromJson,
  ),
  const DwProtocolEntry<ListRoomsOffline>(
    'ListRoomsOffline',
    $ListRoomsOfflineFromJson,
  ),
  const DwProtocolEntry<NoteView>('NoteView', $NoteViewFromJson),
  const DwProtocolEntry<ReadChat>('ReadChat', $ReadChatFromJson),
  const DwProtocolEntry<RenameRoom>('RenameRoom', $RenameRoomFromJson),
  const DwProtocolEntry<RoomView>('RoomView', $RoomViewFromJson),
  const DwProtocolEntry<RoomsTable>('RoomsTable', $RoomsTableFromJson),
], include: DwWireProtocol.core);
