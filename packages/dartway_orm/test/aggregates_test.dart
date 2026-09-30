import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/app_setting.dart';
import 'fixtures/club_service.dart';
import 'fixtures/club_session.dart';
import 'fixtures/generated/dw_schema.dart';
import 'support/test_database.dart';

void main() {
  final database = useTestDatabase();
  DwDatabaseHandle db() => database().db;

  NewClubServiceRow service(
    String title, {
    ClubServiceKind kind = ClubServiceKind.group,
    double? price,
    List<String> tags = const [],
    List<ClubServiceKind> offeredAs = const [],
  }) => NewClubServiceRow(
    title: title,
    kind: kind,
    price: price,
    duration: const Duration(hours: 1),
    tags: tags,
    offeredAs: offeredAs,
    createdAt: DateTime.utc(2026, 9, 1),
  );

  late int yoga;
  late int boxing;

  setUp(() async {
    await db().execute(
      'TRUNCATE app_setting, club_session, club_service RESTART IDENTITY CASCADE',
    );
    yoga = (await db().clubServices.insert(service('Yoga', price: 10))).id;
    boxing = (await db().clubServices.insert(
      service('Boxing', kind: ClubServiceKind.personal),
    )).id;
    await db().clubSessions.insertAll([
      NewClubSessionRow(
        serviceId: yoga,
        startsAt: DateTime.utc(2026, 9, 1, 9),
        capacity: 10,
        labels: const ['morning'],
      ),
      NewClubSessionRow(
        serviceId: yoga,
        startsAt: DateTime.utc(2026, 9, 2, 9),
        capacity: 12,
        note: 'full',
        labels: const [],
      ),
      NewClubSessionRow(
        serviceId: boxing,
        startsAt: DateTime.utc(2026, 9, 1, 18),
        capacity: 4,
        note: 'full',
      ),
    ]);
  });

  group('counting', () {
    test('count(distinct:) counts values, not rows', () async {
      expect(await db().clubSessions.count(), 3);
      expect(await db().clubSessions.count(distinct: (t) => t.serviceId), 2);
      expect(
        await db().clubSessions.count(
          where: (t) => t.note.equals('full'),
          distinct: (t) => t.serviceId,
        ),
        2,
      );
    });

    test('countBy groups, and a group without rows is absent', () async {
      expect(await db().clubSessions.countBy((t) => t.serviceId), {
        yoga: 2,
        boxing: 1,
      });
      expect(
        await db().clubSessions.countBy(
          (t) => t.serviceId,
          where: (t) => t.capacity.gt(5),
        ),
        {yoga: 2},
      );
      expect(await db().clubServices.countBy((t) => t.kind), {
        ClubServiceKind.group: 1,
        ClubServiceKind.personal: 1,
      });
    });
  });

  group('sums and extremes', () {
    test('sum is in the column type, and 0 over no rows', () async {
      final total = await db().clubSessions.sum((t) => t.capacity);
      expect(total, 26);
      expect(total, isA<int>());
      expect(
        await db().clubSessions.sum(
          (t) => t.capacity,
          where: (t) => t.capacity.gt(100),
        ),
        0,
      );
      expect(await db().clubServices.sum((t) => t.price), 10.0);
    });

    test('sumBy per group', () async {
      expect(
        await db().clubSessions.sumBy((t) => t.serviceId, (t) => t.capacity),
        {yoga: 22, boxing: 4},
      );
    });

    test('max and min decode through the column; null over no rows', () async {
      expect(
        await db().clubSessions.max((t) => t.startsAt),
        DateTime.utc(2026, 9, 2, 9),
      );
      expect(await db().clubSessions.min((t) => t.capacity), 4);
      expect(
        await db().clubSessions.max(
          (t) => t.startsAt,
          where: (t) => t.capacity.gt(100),
        ),
        isNull,
      );
      expect(
        await db().clubServices.max((t) => t.price),
        10.0,
        reason: 'the null price of Boxing is not a value',
      );
    });

    test('maxBy and minBy per group; an all-null group is absent', () async {
      expect(
        await db().clubSessions.maxBy((t) => t.serviceId, (t) => t.startsAt),
        {
          yoga: DateTime.utc(2026, 9, 2, 9),
          boxing: DateTime.utc(2026, 9, 1, 18),
        },
      );
      expect(
        await db().clubSessions.minBy((t) => t.serviceId, (t) => t.capacity),
        {yoga: 10, boxing: 4},
      );
      expect(await db().clubServices.maxBy((t) => t.kind, (t) => t.price), {
        ClubServiceKind.group: 10.0,
      });
    });
  });

  test('findFirstPer answers the first row of each group', () async {
    final latest = await db().clubSessions.findFirstPer(
      (t) => t.serviceId,
      orderBy: (t) => [t.startsAt.desc()],
    );
    expect(latest.keys, unorderedEquals([yoga, boxing]));
    expect(latest[yoga]!.startsAt, DateTime.utc(2026, 9, 2, 9));
    expect(latest[boxing]!.capacity, 4);

    final small = await db().clubSessions.findFirstPer(
      (t) => t.serviceId,
      orderBy: (t) => [t.capacity.asc()],
      where: (t) => t.serviceId.equals(yoga),
    );
    expect(small.values.single.capacity, 10);
  });

  test('updateWhereReturning answers the rows as updated', () async {
    final updated = await db().clubSessions.updateWhereReturning(
      where: (t) => t.serviceId.equals(yoga),
      set: (t) => [t.capacity.increment(1), t.note.set('moved')],
    );
    expect(updated.map((row) => row.capacity), unorderedEquals([11, 13]));
    expect(updated.every((row) => row.note == 'moved'), isTrue);
    expect(
      await db().clubSessions.updateWhereReturning(
        where: (t) => t.capacity.gt(100),
        set: (t) => [t.note.set('none')],
      ),
      isEmpty,
    );
  });

  group('upsert', () {
    NewAppSettingRow setting(String key, String value) => NewAppSettingRow(
      key: key,
      value: value,
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    test('inserts, then writes over the row with the same key', () async {
      final first = await db().appSettings.upsert(
        setting('appName', 'Club'),
        conflictOn: (t) => [t.key],
      );
      final second = await db().appSettings.upsert(
        setting('appName', 'Club Two'),
        conflictOn: (t) => [t.key],
      );
      expect(second.id, first.id);
      expect(second.value, 'Club Two');
      expect(await db().appSettings.count(), 1);
    });

    test('concurrent upserts of one key leave one row', () async {
      await Future.wait([
        for (var i = 0; i < 8; i++)
          db().appSettings.upsert(
            setting('signUp', '$i'),
            conflictOn: (t) => [t.key],
          ),
      ]);
      expect(
        await db().appSettings.count(where: (t) => t.key.equals('signUp')),
        1,
      );
    });
  });

  group('upsertAll', () {
    NewAppSettingRow setting(
      String key,
      String value, {
      Map<String, int> limits = const {},
    }) => NewAppSettingRow(
      key: key,
      value: value,
      limits: limits,
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    Future<Map<String, String>> stored() async => {
      for (final row in await db().appSettings.find()) row.key: row.value,
    };

    test('inserts what is missing and counts it', () async {
      final written = await db().appSettings.upsertAll([
        setting('appName', 'Club'),
        setting('signUp', 'true', limits: {'max': 3}),
      ], conflictOn: (t) => [t.key]);
      expect(written, 2);
      expect(await stored(), {'appName': 'Club', 'signUp': 'true'});
    });

    test('run again with the same rows, writes nothing', () async {
      final rows = [
        setting('appName', 'Club'),
        setting('signUp', 'true', limits: {'max': 3}),
      ];
      await db().appSettings.upsertAll(rows, conflictOn: (t) => [t.key]);
      final before = {
        for (final row in await db().appSettings.find()) row.key: row,
      };
      expect(
        await db().appSettings.upsertAll(rows, conflictOn: (t) => [t.key]),
        0,
      );
      final after = {
        for (final row in await db().appSettings.find()) row.key: row,
      };
      expect(after, before, reason: 'ids and values stay as they were');
    });

    test('an unchanged row is not rewritten', () async {
      Future<Map<String, String>> versions() async => {
        for (final row in await db().query(
          'SELECT "key", xmin::text AS version FROM app_setting',
        ))
          row.get<String>('key'): row.get<String>('version'),
      };
      final rows = [setting('appName', 'Club'), setting('signUp', 'true')];
      await db().appSettings.upsertAll(rows, conflictOn: (t) => [t.key]);
      final first = await versions();
      await db().appSettings.upsertAll(rows, conflictOn: (t) => [t.key]);
      expect(await versions(), first);
    });

    test('writes a changed row over the stored one, by its key', () async {
      await db().appSettings.upsertAll([
        setting('appName', 'Club'),
        setting('signUp', 'true'),
      ], conflictOn: (t) => [t.key]);
      final id = (await db().appSettings.findFirst(
        where: (t) => t.key.equals('appName'),
      ))!.id;
      expect(
        await db().appSettings.upsertAll([
          setting('appName', 'Club Two'),
          setting('signUp', 'true'),
        ], conflictOn: (t) => [t.key]),
        1,
      );
      final renamed = (await db().appSettings.findFirst(
        where: (t) => t.key.equals('appName'),
      ))!;
      expect(renamed.id, id);
      expect(renamed.value, 'Club Two');
    });

    test('leaves rows it does not name alone', () async {
      await db().appSettings.insert(setting('theme', 'dark'));
      await db().appSettings.upsertAll([
        setting('appName', 'Club'),
      ], conflictOn: (t) => [t.key]);
      expect(await stored(), {'theme': 'dark', 'appName': 'Club'});
    });

    test('refuses two rows with one key', () async {
      await expectLater(
        db().appSettings.upsertAll([
          setting('appName', 'A'),
          setting('appName', 'B'),
        ], conflictOn: (t) => [t.key]),
        throwsArgumentError,
      );
      expect(await db().appSettings.count(), 0);
    });

    test('refuses a nullable conflict column', () async {
      await expectLater(
        db().appSettings.upsertAll([
          setting('appName', 'A'),
        ], conflictOn: (t) => [t.featuredServiceId]),
        throwsArgumentError,
      );
    });

    test('nothing is sent for no rows', () async {
      expect(
        await db().appSettings.upsertAll(const [], conflictOn: (t) => [t.key]),
        0,
      );
    });
  });

  group('jsonb lists', () {
    setUp(() async {
      await db().clubServices.insertAll([
        service(
          'Pilates',
          tags: ['core', 'mat'],
          offeredAs: [ClubServiceKind.personal],
        ),
        service('Swim', tags: ['pool']),
      ]);
    });

    Future<List<String>> titles(
      DwWhereCondition Function(ClubServiceTable t) where,
    ) async => [
      for (final row in await db().clubServices.find(
        where: where,
        orderBy: (t) => [t.title.asc()],
      ))
        row.title,
    ];

    test('isEmptyList and isNotEmptyList', () async {
      expect(await titles((t) => t.tags.isNotEmptyList()), ['Pilates', 'Swim']);
      expect(await titles((t) => t.tags.isEmptyList()), ['Boxing', 'Yoga']);
      expect(
        await db().clubSessions.count(where: (t) => t.labels.isEmptyList()),
        1,
        reason: 'a null list is neither empty nor not',
      );
    });

    test('contains and containsAny', () async {
      expect(await titles((t) => t.tags.contains('mat')), ['Pilates']);
      expect(await titles((t) => t.tags.containsAny(['pool', 'core'])), [
        'Pilates',
        'Swim',
      ]);
      expect(await titles((t) => t.tags.containsAny(const [])), isEmpty);
      expect(
        await titles((t) => t.offeredAs.contains(ClubServiceKind.personal)),
        ['Pilates'],
        reason: 'an enum list matches by the names it stores',
      );
    });
  });
}
