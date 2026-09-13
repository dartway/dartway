// DTOs in the exact shape `dartway generate` produces, written by hand.

import 'package:dartway_flutter/dartway_flutter.dart';

enum AppChannel with DwChannelKind { rooms }

const roomsChannel = DwChannel(AppChannel.rooms);

final class RoomView extends DwDataObject with _$RoomView {
  const RoomView({required this.id, required this.name});

  @override
  final int id;
  final String name;
}

mixin _$RoomView on DwDataObject {
  RoomView get _self => this as RoomView;
  @override
  String get dwTypeName => 'RoomView';
  @override
  Map<String, Object?> toJson() => {'id': _self.id, 'name': _self.name};
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomView && other.id == _self.id && other.name == _self.name;
  @override
  int get hashCode => Object.hash(_self.id, _self.name);
}

RoomView $RoomViewFromJson(Map<String, Object?> json) =>
    RoomView(id: json['id']! as int, name: json['name']! as String);

final class ListRooms extends DwListRequest<RoomView> with _$ListRooms {
  const ListRooms();

  @override
  List<DwChannel> get channels => const [roomsChannel];
}

mixin _$ListRooms on DwListRequest<RoomView> {
  @override
  String get dwTypeName => 'ListRooms';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is ListRooms;
  @override
  int get hashCode => (ListRooms).hashCode;
}

ListRooms $ListRoomsFromJson(Map<String, Object?> json) => const ListRooms();

final class FeedRooms extends DwPageRequest<RoomView> with _$FeedRooms {
  const FeedRooms();

  @override
  int get pageSize => 2;

  @override
  List<DwChannel> get channels => const [roomsChannel];
}

mixin _$FeedRooms on DwPageRequest<RoomView> {
  @override
  String get dwTypeName => 'FeedRooms';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is FeedRooms;
  @override
  int get hashCode => (FeedRooms).hashCode;
}

FeedRooms $FeedRoomsFromJson(Map<String, Object?> json) => const FeedRooms();

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
  DwDtoEntry(ListRooms, 'ListRooms', $ListRoomsFromJson),
  DwDtoEntry(RenameRoom, 'RenameRoom', $RenameRoomFromJson),
  DwDtoEntry(RoomView, 'RoomView', $RoomViewFromJson),
], include: DwProtocol.core);
