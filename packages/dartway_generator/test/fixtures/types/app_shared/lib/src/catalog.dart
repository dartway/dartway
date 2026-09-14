import 'dart:typed_data';

import 'package:dartway_core/dartway_core.dart';

import 'units.dart' as units;

part 'catalog.dw.dart';

enum Color { red, green, blue }

/// An abstract base: not generated itself, its fields are inherited.
abstract class Named extends DwDataObject {
  const Named({required this.title});

  final String title;
}

final class Item extends Named with _$Item {
  const Item({
    required this.id,
    required super.title,
    required this.price,
    this.discount,
    required this.duration,
    this.timeout,
    required this.image,
    this.thumbnail,
    required this.color,
    this.colors = const [],
    this.labels = const {},
    required this.createdAt,
    this.updatedAt,
    this.weight = 0,
    required this.unit,
    this.parent,
    this.children = const [],
    required this.ratings,
    this.scores,
    this.history = const {},
    this.maybeColors = const <Color?>[],
    required this.dimensions,
    this.allDimensions = const [],
  });

  @override
  final int id;
  final int price;
  final double? discount;
  final Duration duration;
  final Duration? timeout;
  final Uint8List image;
  final Uint8List? thumbnail;
  final Color color;
  final List<Color> colors;
  final Map<String, String> labels;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int weight;
  final units.Unit unit;
  final Item? parent;
  final List<Item> children;
  final List<double> ratings;
  final Map<String, int>? scores;
  final Map<String, DateTime?> history;
  final List<Color?> maybeColors;
  final units.Dimensions dimensions;
  final List<units.Dimensions?> allDimensions;

  /// Not serialised: a getter.
  bool get isDiscounted => discount != null;

  /// Not serialised: initialised at the declaration.
  static const kind = 'item';

  final String cacheKey = 'item';
}

/// A singleton view: its id is a getter.
final class Stats extends DwDataObject with _$Stats {
  const Stats({required this.count});

  @override
  String get id => 'stats';

  final int count;
}

/// Only an id.
final class Ref extends DwDataObject with _$Ref {
  const Ref({required this.id});

  @override
  final String id;
}

/// A framework DTO nested in a project one.
final class SessionHolder extends DwDataObject with _$SessionHolder {
  const SessionHolder({required this.id, required this.session, this.previous});

  @override
  final int id;
  final DwAuthSession session;
  final DwAuthSession? previous;
}

final class GetItem extends DwSingleRequest<Item> with _$GetItem {
  const GetItem({required this.id});

  final int id;
}

final class FindItem extends DwMaybeRequest<Item> with _$FindItem {
  const FindItem({this.title, this.colors = const []});

  final String? title;
  final List<Color> colors;

  /// Not serialised: a method.
  @override
  bool matches(Item item) => item.title == title;
}

/// Page sizes are super-constructor arguments: constants, not serialised.
final class ListItems extends DwPageRequest<Item> with _$ListItems {
  const ListItems({this.color, this.since, this.labels})
    : super(pageSize: 20, maxPageSize: 100);

  final Color? color;
  final DateTime? since;
  final Map<String, String>? labels;
}

/// A named super constructor, and an optional super parameter that stays off
/// the wire.
final class FeedItems extends DwPageRequest<Item> with _$FeedItems {
  const FeedItems({super.maxPageSize}) : super.updateOnly(pageSize: 40);
}

final class ListPinnedItems extends DwListRequest<Item> with _$ListPinnedItems {
  const ListPinnedItems({required this.pinnedBy}) : super.refetchOnUpdate();

  final String pinnedBy;
}

/// A table's page and page size are ordinary fields: they are its key.
final class ItemTable extends DwTableRequest<Item> with _$ItemTable {
  const ItemTable({this.page = 1, this.pageSize = 25, this.color})
    : super(maxPageSize: 100);

  @override
  final int page;

  @override
  final int pageSize;

  final Color? color;
}

final class ItemHistory extends DwWindowRequest<Item> with _$ItemHistory {
  const ItemHistory({required this.itemId}) : super(pageSize: 50);

  final int itemId;
}

final class EditItem extends DwActionCommand<Item> with _$EditItem {
  const EditItem({
    required this.itemId,
    this.title = const DwFieldPatch.keep(),
    this.updatedAt = const DwFieldPatch.keep(),
    this.color = const DwFieldPatch.keep(),
    this.dimensions = const DwFieldPatch.keep(),
    this.discount = const DwFieldPatch.keep(),
    this.timeout = const DwFieldPatch.keep(),
    this.tags = const [],
  });

  final int itemId;
  final DwFieldPatch<String> title;
  final DwFieldPatch<DateTime> updatedAt;
  final DwFieldPatch<Color> color;
  final DwFieldPatch<units.Dimensions> dimensions;
  final DwFieldPatch<double> discount;
  final DwFieldPatch<Duration> timeout;
  final List<String> tags;
}

final class OnlyPatches extends DwActionCommand<void> with _$OnlyPatches {
  const OnlyPatches({this.note = const DwFieldPatch.keep()});

  final DwFieldPatch<String> note;
}

final class RemoveItem extends DwActionCommand<void> with _$RemoveItem {
  const RemoveItem();
}

/// More fields than `Object.hash` takes.
final class WideRequest extends DwListRequest<Item> with _$WideRequest {
  const WideRequest({
    this.a1 = 0,
    this.a2 = 0,
    this.a3 = 0,
    this.a4 = 0,
    this.a5 = 0,
    this.a6 = 0,
    this.a7 = 0,
    this.a8 = 0,
    this.a9 = 0,
    this.a10 = 0,
    this.a11 = 0,
    this.a12 = 0,
    this.a13 = 0,
    this.a14 = 0,
    this.a15 = 0,
    this.a16 = 0,
    this.a17 = 0,
    this.a18 = 0,
    this.a19 = 0,
    this.a20 = 0,
  });

  final int a1;
  final int a2;
  final int a3;
  final int a4;
  final int a5;
  final int a6;
  final int a7;
  final int a8;
  final int a9;
  final int a10;
  final int a11;
  final int a12;
  final int a13;
  final int a14;
  final int a15;
  final int a16;
  final int a17;
  final int a18;
  final int a19;
  final int a20;
}
