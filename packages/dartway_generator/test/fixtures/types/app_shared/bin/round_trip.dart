import 'dart:convert';
import 'dart:typed_data';

import 'package:app_shared/app_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';

/// Encodes and decodes every generated DTO through real JSON text and checks
/// that nothing is lost: equality, hash, omission rules, patches, copyWith.
void main() {
  final failures = <String>[];
  void check(bool condition, String what) {
    if (!condition) failures.add(what);
  }

  Object? wire(Object? json) => jsonDecode(jsonEncode(json));

  T roundTrip<T extends DwWireObject>(T dto) {
    // Untagged, as the wire carries it: the type comes from the registry,
    // once by the static type and once by the wire name.
    final json = wire(dto.toJson());
    final back = appProtocol.decodeAs<T>(json);
    check(
      appProtocol.decodeNamed(dto.dwTypeName, json) == dto,
      '$T decodes by its wire name',
    );
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
  check(!minimalJson.containsKey('weight'), 'a scalar default is omitted');
  check(
    full.toJson()['weight'] == 3,
    'a scalar differing from its default is written',
  );
  check(
    full != minimal && full.hashCode != minimal.hashCode,
    'different items differ',
  );

  // copyWith: plain fields replace, nullable fields take a patch.
  final edited = full.copyWith(
    title: 'New',
    discount: const DwFieldPatch.clear(),
    timeout: const DwFieldPatch.set(Duration(seconds: 9)),
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
      session: DwAuthSession(id: 5, token: 't', isNewAccount: true),
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
  roundTrip(
    ListItems(color: Color.red, since: DateTime.utc(2026), labels: const {}),
  );
  roundTrip(const ListItems());
  roundTrip(const FeedItems());
  check(
    const FeedItems(maxPageSize: 400).toJson().isEmpty &&
        const FeedItems().pageSize == 40,
    'super arguments and super parameters are not serialised',
  );
  roundTrip(const ListPinnedItems(pinnedBy: 'me'));
  roundTrip(const ItemTable());
  roundTrip(const ItemTable(page: 3, pageSize: 10, color: Color.blue));
  check(
    const ItemTable(page: 2).toJson()['page'] == 2 &&
        const ItemTable(page: 2) != const ItemTable(page: 3),
    'a table page is a serialised field and part of the key',
  );
  roundTrip(const ItemHistory(itemId: 4));
  roundTrip(const WideRequest(a1: 1, a20: 20));
  check(
    const WideRequest(a1: 1) != const WideRequest(a2: 1),
    'wide request compares every field',
  );

  // Patches: keep is absent, clear is an explicit null, set carries a value.
  for (final patch in const [
    DwFieldPatch<Dimensions>.keep(),
    DwFieldPatch<Dimensions>.clear(),
    DwFieldPatch<Dimensions>.set(dimensions),
  ]) {
    final command = EditItem(
      itemId: 1,
      title: const DwFieldPatch.set('x'),
      updatedAt: DwFieldPatch.set(DateTime.utc(2026, 1, 2)),
      color: const DwFieldPatch.clear(),
      dimensions: patch,
      discount: const DwFieldPatch.set(2),
      timeout: const DwFieldPatch.set(Duration(milliseconds: 5)),
      tags: const ['a'],
    );
    final back = roundTrip(command);
    check(back.dimensions == patch, 'patch $patch survives');
  }
  final keptJson = const EditItem(itemId: 1).toJson();
  check(
    keptJson.keys.toList().join(',') == 'itemId',
    'kept patches are absent',
  );
  final clearedJson =
      wire(const EditItem(itemId: 1, color: DwFieldPatch.clear()).toJson())
          as Map<String, Object?>;
  check(
    clearedJson.containsKey('color') && clearedJson['color'] == null,
    'a cleared patch is an explicit null',
  );
  roundTrip(const OnlyPatches(note: DwFieldPatch.set('n')));
  roundTrip(const RemoveItem());

  // Defaults (D-041): an absent field decodes to its default, a value equal
  // to its default stays off the wire.
  final created = DateTime.utc(2026, 9, 14);
  final defaults = Settings(id: 1, createdAt: created);
  final defaultsJson = wire(defaults.toJson())! as Map<String, Object?>;
  check(
    defaultsJson.keys.toList().join(',') == 'id,createdAt',
    'defaults are omitted, got ${defaultsJson.keys}',
  );
  roundTrip(defaults);
  check(
    appProtocol.decodeAs<Settings>(<String, Object?>{
          'id': 1,
          'createdAt': DwJsonCodec.encodeDateTime(created),
        }) ==
        defaults,
    'a JSON without defaulted fields decodes to the defaults',
  );
  final decodedDefaults = appProtocol.decodeAs<Settings>(defaultsJson);
  check(
    decodedDefaults.count == 3 &&
        decodedDefaults.offset == -1 &&
        decodedDefaults.enabled &&
        decodedDefaults.title == defaultTitle &&
        decodedDefaults.escaped == 'it\'s \$5\n\\' &&
        decodedDefaults.ratio == 1 &&
        decodedDefaults.color == Color.green &&
        decodedDefaults.unit == Unit.kg &&
        decodedDefaults.timeout == const Duration(seconds: 30) &&
        decodedDefaults.label == 'none' &&
        decodedDefaults.maybeColor == Color.red &&
        decodedDefaults.note == null &&
        decodedDefaults.startsAt == null &&
        decodedDefaults.tags.join(',') == 'a,b' &&
        decodedDefaults.empty.isEmpty &&
        decodedDefaults.limits['max'] == 10 &&
        decodedDefaults.noLimits.isEmpty &&
        decodedDefaults.maybeTags!.single == 'x' &&
        decodedDefaults.dimensions ==
            const Dimensions(id: 'default', width: 1) &&
        decodedDefaults.shelf.single.height == 0.5 &&
        decodedDefaults.ref == Settings.fallbackRef &&
        decodedDefaults.loose == const Loose.fixed(),
    'every default is applied',
  );
  final changed = Settings(
    id: 2,
    count: 0,
    offset: 0,
    enabled: false,
    title: '',
    escaped: '',
    ratio: 0.5,
    color: Color.red,
    unit: Unit.pcs,
    timeout: Duration.zero,
    label: null,
    maybeColor: null,
    note: 'n',
    createdAt: created,
    startsAt: created,
    tags: const [],
    empty: const [1],
    limits: const {'max': 10},
    noLimits: const {'x': true},
    maybeTags: null,
    dimensions: const Dimensions(id: 'default', width: 1, height: 2),
    shelf: const [],
    ref: const Ref(id: 'other'),
    loose: Loose(id: 'loose'),
  );
  final changedBack = roundTrip(changed);
  final changedJson = wire(changed.toJson())! as Map<String, Object?>;
  check(changedJson.length == 24, 'every changed field is written');
  check(
    changedJson.containsKey('label') && changedJson['label'] == null,
    'null differing from a non-null default is an explicit null',
  );
  check(
    changedBack.label == null &&
        changedBack.maybeColor == null &&
        changedBack.maybeTags == null,
    'an explicit null decodes to null, not to the default',
  );
  check(
    appProtocol.decodeAs<Settings>({
          ...changedJson,
          'count': null,
          'tags': null,
        }).count ==
        3,
    'a null non-nullable defaulted field decodes to its default',
  );

  roundTrip(const SearchItems());
  check(
    const SearchItems().toJson().isEmpty,
    'a request with only defaults is empty on the wire',
  );
  check(
    appProtocol.decodeAs<SearchItems>(const <String, Object?>{}) ==
        const SearchItems(),
    'an empty request body decodes to the defaults',
  );
  roundTrip(
    SearchItems(query: 'q', limit: 1, colors: const [], since: created),
  );
  check(
    const UpdateSettings(settingsId: 1).toJson().keys.join(',') == 'settingsId',
    'a command omits a kept patch and a default',
  );
  roundTrip(
    const UpdateSettings(
      settingsId: 1,
      title: DwFieldPatch.clear(),
      notify: false,
    ),
  );
  check(
    appProtocol.decodeAs<UpdateSettings>(const {'settingsId': 1}) ==
        const UpdateSettings(settingsId: 1),
    'a command without defaulted fields decodes',
  );
  var missingRequired = false;
  try {
    appProtocol.decodeAs<Settings>(const {'id': 1});
  } on Object {
    missingRequired = true;
  }
  check(missingRequired, 'a required field without default stays required');

  if (failures.isEmpty) {
    print('ok');
  } else {
    print(failures.join('\n'));
    throw StateError('${failures.length} round-trip checks failed');
  }
}
