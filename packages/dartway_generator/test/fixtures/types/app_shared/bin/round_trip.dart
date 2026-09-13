import 'dart:convert';
import 'dart:typed_data';

import 'package:app_shared/app_shared.dart';
import 'package:dartway_core/dartway_core.dart';

/// Encodes and decodes every generated DTO through real JSON text and checks
/// that nothing is lost: equality, hash, omission rules, patches, copyWith.
void main() {
  final failures = <String>[];
  void check(bool condition, String what) {
    if (!condition) failures.add(what);
  }

  Object? wire(Object? json) => jsonDecode(jsonEncode(json));

  T roundTrip<T extends DwDto>(T dto) {
    final tagged = wire(appProtocol.encodeTagged(dto));
    final back = appProtocol.decodeTagged(tagged) as T;
    check(back == dto, '$T round trip equality');
    check(back.hashCode == dto.hashCode, '$T round trip hash');
    return back;
  }

  const dimensions = Dimensions(id: 'd1', width: 2, height: 3.5);
  final full = Item(
    id: 1,
    title: 'Mat',
    price: 100,
    discount: 0.5,
    duration: const Duration(minutes: 90),
    timeout: const Duration(seconds: 3),
    image: Uint8List.fromList([1, 2, 3]),
    thumbnail: Uint8List.fromList([4]),
    color: Color.green,
    colors: const [Color.red, Color.blue],
    labels: const {'a': 'b'},
    createdAt: DateTime.utc(2026, 9, 13, 10, 0, 0, 123, 456),
    // DateTime equality includes isUtc; the wire carries the instant and
    // decodes it as UTC, so a value meant to round-trip is UTC.
    updatedAt: DateTime.utc(2026, 9, 14),
    weight: 3,
    unit: Unit.kg,
    parent: Item(
      id: 0,
      title: 'Parent',
      price: 1,
      duration: Duration.zero,
      image: Uint8List(0),
      color: Color.red,
      createdAt: DateTime.utc(2020),
      unit: Unit.pcs,
      ratings: const [],
      dimensions: const Dimensions(id: 'p', width: 1),
    ),
    children: [
      Item(
        id: 2,
        title: 'Child',
        price: 2,
        duration: Duration.zero,
        image: Uint8List(0),
        color: Color.blue,
        createdAt: DateTime.utc(2021),
        unit: Unit.pcs,
        ratings: const [1],
        dimensions: dimensions,
      ),
    ],
    ratings: const [4.5, 5],
    scores: const {'x': 1},
    history: {'created': DateTime.utc(2026), 'deleted': null},
    maybeColors: const [null, Color.red],
    dimensions: dimensions,
    allDimensions: const [dimensions, null],
  );
  final fullBack = roundTrip(full);
  check(fullBack.updatedAt!.isUtc, 'DateTime decodes as UTC');
  check(
    fullBack.ratings.last.runtimeType == double,
    'whole double decodes as double',
  );

  final minimal = Item(
    id: 3,
    title: 'Bare',
    price: 0,
    duration: Duration.zero,
    image: Uint8List(0),
    color: Color.red,
    createdAt: DateTime.utc(2026),
    unit: Unit.pcs,
    ratings: const [],
    dimensions: const Dimensions(id: 'm', width: 0),
  );
  roundTrip(minimal);
  final minimalJson = minimal.toJson();
  for (final absent in [
    'discount',
    'timeout',
    'thumbnail',
    'colors',
    'labels',
    'updatedAt',
    'parent',
    'children',
    'scores',
    'history',
    'maybeColors',
    'allDimensions',
  ]) {
    check(!minimalJson.containsKey(absent), 'Item omits empty/null $absent');
  }
  check(minimalJson.containsKey('ratings'), 'a list without default is kept');
  check(minimalJson['weight'] == 0, 'a scalar default is still written');
  check(
    full != minimal && full.hashCode != minimal.hashCode,
    'different items differ',
  );

  // copyWith: plain fields replace, nullable fields take a patch.
  final edited = full.copyWith(
    title: 'New',
    discount: const DwPatch.clear(),
    timeout: const DwPatch.set(Duration(seconds: 9)),
  );
  check(edited.title == 'New', 'copyWith sets a plain field');
  check(edited.discount == null, 'copyWith clears through a patch');
  check(edited.timeout == const Duration(seconds: 9), 'copyWith sets a patch');
  check(edited.thumbnail == full.thumbnail, 'copyWith keeps by default');
  check(full.copyWith() == full, 'copyWith() is equal');

  roundTrip(const Stats(count: 7));
  check(const Stats(count: 7).toJson().length == 1, 'id getter not serialised');
  roundTrip(const Ref(id: 'r'));
  roundTrip(
    const SessionHolder(
      id: 1,
      session: DwSession(id: 5, token: 't', isNewAccount: true),
    ),
  );

  // Requests are value keys: equal fields, equal requests; other classes
  // with the same (no) fields are different.
  check(const GetItem(id: 1) == const GetItem(id: 1), 'request equality');
  check(
    (const FeedItems() as Object) != const RemoveItem(),
    'distinct empty DTOs',
  );
  check(
    const FeedItems().hashCode != const RemoveItem().hashCode,
    'distinct empty DTO hashes',
  );
  roundTrip(const GetItem(id: 1));
  roundTrip(const FindItem());
  roundTrip(const FindItem(title: 't', colors: [Color.green]));
  roundTrip(ListItems(color: Color.red, since: DateTime.utc(2026), labels: const {}));
  roundTrip(const ListItems());
  roundTrip(const FeedItems());
  roundTrip(const WideRequest(a1: 1, a20: 20));
  check(
    const WideRequest(a1: 1) != const WideRequest(a2: 1),
    'wide request compares every field',
  );

  // Patches: keep is absent, clear is an explicit null, set carries a value.
  for (final patch in const [
    DwPatch<Dimensions>.keep(),
    DwPatch<Dimensions>.clear(),
    DwPatch<Dimensions>.set(dimensions),
  ]) {
    final command = EditItem(
      itemId: 1,
      title: const DwPatch.set('x'),
      updatedAt: DwPatch.set(DateTime.utc(2026, 1, 2)),
      color: const DwPatch.clear(),
      dimensions: patch,
      discount: const DwPatch.set(2),
      timeout: const DwPatch.set(Duration(milliseconds: 5)),
      tags: const ['a'],
    );
    final back = roundTrip(command);
    check(back.dimensions == patch, 'patch $patch survives');
  }
  final keptJson = const EditItem(itemId: 1).toJson();
  check(keptJson.keys.toList().join(',') == 'itemId', 'kept patches are absent');
  final clearedJson = wire(
    const EditItem(itemId: 1, color: DwPatch.clear()).toJson(),
  ) as Map<String, Object?>;
  check(
    clearedJson.containsKey('color') && clearedJson['color'] == null,
    'a cleared patch is an explicit null',
  );
  roundTrip(const OnlyPatches(note: DwPatch.set('n')));
  roundTrip(const RemoveItem());

  if (failures.isEmpty) {
    print('ok');
  } else {
    print(failures.join('\n'));
    throw StateError('${failures.length} round-trip checks failed');
  }
}
