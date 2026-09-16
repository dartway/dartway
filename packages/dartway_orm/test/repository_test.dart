import 'dart:typed_data';

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

  ClubServiceRow service({
    String title = 'Yoga',
    ClubServiceKind kind = ClubServiceKind.group,
    double? price,
    Duration duration = const Duration(hours: 1),
    List<String> tags = const [],
    List<ClubServiceKind> offeredAs = const [],
    DateTime? createdAt,
    DateTime? archivedAt,
    Uint8List? cover,
    bool active = true,
  }) => ClubServiceRow(
    title: title,
    kind: kind,
    price: price,
    duration: duration,
    tags: tags,
    offeredAs: offeredAs,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 1, 10),
    archivedAt: archivedAt,
    cover: cover,
    active: active,
  );

  setUp(() async {
    await db().execute(
      'TRUNCATE app_setting, club_session, club_service RESTART IDENTITY CASCADE',
    );
  });

  group('insert and read back', () {
    test('every column type round-trips', () async {
      final local = DateTime(2026, 9, 13, 12, 30, 15, 123, 456);
      final stored = await db().clubServices.insert(
        service(
          title: 'Stretch "and" \'quotes\'',
          kind: ClubServiceKind.personal,
          price: 12.5,
          duration: const Duration(days: 400, microseconds: 7),
          tags: ['a', 'b, c', '"quoted"'],
          createdAt: local,
          archivedAt: DateTime.utc(2027, 1, 1),
          cover: Uint8List.fromList([0, 1, 254, 255]),
          active: false,
        ),
      );
      expect(stored.id, 1);
      expect(stored.createdAt.isUtc, isTrue);
      expect(stored.createdAt, local.toUtc());
      expect(stored.duration, const Duration(days: 400, microseconds: 7));
      expect(stored.tags, ['a', 'b, c', '"quoted"']);
      expect(stored.cover, [0, 1, 254, 255]);
      expect(stored.kind, ClubServiceKind.personal);
      expect(stored.active, isFalse);

      final read = await db().clubServices.findById(stored.id!);
      expect(read, stored);
    });

    test('nulls round-trip as SQL NULL', () async {
      final stored = await db().clubServices.insert(service());
      expect(stored.price, isNull);
      expect(stored.archivedAt, isNull);
      expect(stored.cover, isNull);
      final raw = await db().query(
        'SELECT price IS NULL AS p, archived_at IS NULL AS a, cover IS NULL AS c '
        'FROM club_service WHERE id = @id',
        params: {'id': stored.id},
      );
      expect(raw.single, {'p': true, 'a': true, 'c': true});
    });

    test('the enum is stored as its name', () async {
      await db().clubServices.insert(service(kind: ClubServiceKind.personal));
      final raw = await db().query('SELECT kind FROM club_service');
      expect(raw.single.get<String>('kind'), 'personal');
    });

    test('a Duration is stored as bigint microseconds', () async {
      await db().clubServices.insert(
        service(duration: const Duration(seconds: 2)),
      );
      final raw = await db().query('SELECT duration FROM club_service');
      expect(raw.single.get<int>('duration'), 2000000);
    });

    test('an explicit id is written', () async {
      final stored = await db().clubServices.insert(
        service().copyWith(id: const DwFieldPatch.set(42)),
      );
      expect(stored.id, 42);
    });

    test('jsonb map, keyword-named columns, unique foreign key', () async {
      final yoga = await db().clubServices.insert(service());
      final setting = await db().appSettings.insert(
        AppSettingRow(
          key: 'limits',
          value: 'text value',
          limits: {'daily': 3, 'weekly': 10},
          featuredServiceId: yoga.id,
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(setting.limits, {'daily': 3, 'weekly': 10});
      final found = await db().appSettings.findFirst(
        where: (t) => t.key.equals('limits') & t.value.equals('text value'),
      );
      expect(found, setting);
    });

    test('a list of an enum is stored as its names and read back', () async {
      final one = await db().clubServices.insert(
        service(offeredAs: [ClubServiceKind.personal, ClubServiceKind.group]),
      );
      final many = await db().clubServices.insertAll([
        service(title: 'Empty'),
        service(title: 'One', offeredAs: [ClubServiceKind.personal]),
      ]);
      expect(await db().clubServices.findById(one.id!), one);
      expect(one.offeredAs, [ClubServiceKind.personal, ClubServiceKind.group]);
      expect(
        [
          for (final row in many)
            (await db().clubServices.findById(row.id!))!.offeredAs,
        ],
        [
          const <ClubServiceKind>[],
          [ClubServiceKind.personal],
        ],
      );
      final stored = (await db().query(
        "SELECT offered_as::text AS names FROM club_service WHERE id = @id",
        params: {'id': one.id},
      )).single;
      expect(stored['names'], '["personal", "group"]');
    });

    test(
      'a list of an enum holding a name no value has fails loudly',
      () async {
        await db().execute(
          "INSERT INTO club_service (title, kind, duration, tags, offered_as, "
          "created_at) VALUES ('x', 'group', 1, '[]', '[\"retired\"]', now())",
        );
        expect(db().clubServices.find(), throwsA(isA<DwDecodeException>()));
      },
    );

    test(
      'a decoded row that does not fit the row class fails loudly',
      () async {
        await db().execute(
          "INSERT INTO club_service (title, kind, duration, tags, offered_as, "
          "created_at) VALUES ('x', 'unknown', 1, '[]', '[]', now())",
        );
        expect(db().clubServices.find(), throwsA(isA<DwDecodeException>()));
      },
    );
  });

  group('find', () {
    late List<ClubServiceRow> services;

    setUp(() async {
      services = await db().clubServices.insertAll([
        service(
          title: 'Alpha',
          price: 10,
          duration: const Duration(minutes: 30),
        ),
        service(
          title: 'beta',
          price: 20,
          kind: ClubServiceKind.personal,
          duration: const Duration(minutes: 60),
          createdAt: DateTime.utc(2026, 9, 2),
        ),
        service(
          title: 'Gamma',
          duration: const Duration(minutes: 90),
          createdAt: DateTime.utc(2026, 9, 3),
          archivedAt: DateTime.utc(2026, 9, 4),
        ),
      ]);
    });

    Future<List<String>> titles(
      DwWhereCondition Function(ClubServiceTable t)? where,
    ) async => [
      for (final found in await db().clubServices.find(
        where: where,
        orderBy: (t) => [t.id.asc()],
      ))
        found.title,
    ];

    test('equals and notEquals follow Dart null semantics', () async {
      expect(await titles((t) => t.title.equals('beta')), ['beta']);
      expect(await titles((t) => t.price.equals(null)), ['Gamma']);
      expect(await titles((t) => t.price.notEquals(null)), ['Alpha', 'beta']);
      // A null price is not equal to 10, so Gamma matches.
      expect(await titles((t) => t.price.notEquals(10)), ['beta', 'Gamma']);
      expect(await titles((t) => t.title.notEquals('beta')), [
        'Alpha',
        'Gamma',
      ]);
    });

    test('isNull and isNotNull', () async {
      expect(await titles((t) => t.archivedAt.isNull()), ['Alpha', 'beta']);
      expect(await titles((t) => t.archivedAt.isNotNull()), ['Gamma']);
    });

    test('inList and notInList', () async {
      expect(await titles((t) => t.title.inList(['Alpha', 'Gamma', 'nope'])), [
        'Alpha',
        'Gamma',
      ]);
      expect(await titles((t) => t.title.inList(const [])), isEmpty);
      expect(await titles((t) => t.price.notInList([10])), ['beta', 'Gamma']);
      expect(await titles((t) => t.title.notInList(const [])), hasLength(3));
      expect(await titles((t) => t.kind.inList([ClubServiceKind.personal])), [
        'beta',
      ]);
      expect(
        await titles(
          (t) => t.duration.inList(const [
            Duration(minutes: 30),
            Duration(minutes: 90),
          ]),
        ),
        ['Alpha', 'Gamma'],
      );
    });

    test('comparisons on int, double, DateTime, Duration and String', () async {
      expect(await titles((t) => t.id.gt(services[0].id!)), ['beta', 'Gamma']);
      expect(await titles((t) => t.price.gte(20)), ['beta']);
      expect(await titles((t) => t.price.lt(20)), ['Alpha']);
      expect(await titles((t) => t.createdAt.lte(DateTime.utc(2026, 9, 2))), [
        'Alpha',
        'beta',
      ]);
      expect(
        await titles(
          (t) => t.duration.between(
            const Duration(minutes: 45),
            const Duration(minutes: 90),
          ),
        ),
        ['beta', 'Gamma'],
      );
      expect(await titles((t) => t.title.gt('Alpha')), ['beta', 'Gamma']);
    });

    test('like and ilike', () async {
      expect(await titles((t) => t.title.like('%a')), [
        'Alpha',
        'beta',
        'Gamma',
      ]);
      expect(await titles((t) => t.title.like('A%')), ['Alpha']);
      expect(await titles((t) => t.title.ilike('b%')), ['beta']);
    });

    test(
      '&, | and not() — not() of a comparison against null is true',
      () async {
        expect(
          await titles(
            (t) => t.price.gte(10) & t.kind.equals(ClubServiceKind.group),
          ),
          ['Alpha'],
        );
        expect(
          await titles(
            (t) => t.title.equals('Alpha') | t.archivedAt.isNotNull(),
          ),
          ['Alpha', 'Gamma'],
        );
        expect(await titles((t) => t.price.gt(15).not()), ['Alpha', 'Gamma']);
        expect(
          await titles((t) => (t.price.gt(15) | t.title.equals('Gamma')).not()),
          ['Alpha'],
        );
      },
    );

    test('orderBy, limit and offset', () async {
      final page = await db().clubServices.find(
        orderBy: (t) => [t.kind.desc(), t.title.asc()],
        limit: 2,
        offset: 1,
      );
      expect(page.map((s) => s.title), ['Alpha', 'Gamma']);
      expect(
        () => db().clubServices.find(limit: -1),
        throwsA(isA<RangeError>()),
      );
    });

    test('findFirst, count, exists', () async {
      final first = await db().clubServices.findFirst(
        where: (t) => t.price.isNotNull(),
        orderBy: (t) => [t.price.desc()],
      );
      expect(first!.title, 'beta');
      expect(
        await db().clubServices.findFirst(where: (t) => t.title.equals('none')),
        isNull,
      );
      expect(await db().clubServices.count(), 3);
      expect(await db().clubServices.count(where: (t) => t.price.isNull()), 1);
      expect(
        await db().clubServices.exists(where: (t) => t.title.equals('beta')),
        isTrue,
      );
      expect(
        await db().clubServices.exists(where: (t) => t.title.equals('zeta')),
        isFalse,
      );
    });

    test('findById and findByIds', () async {
      expect(await db().clubServices.findById(999), isNull);
      final found = await db().clubServices.findByIds([
        services[2].id!,
        services[0].id!,
        services[0].id!,
        999,
      ]);
      expect(found.map((s) => s.id).toSet(), {services[0].id, services[2].id});
      expect(await db().clubServices.findByIds(const []), isEmpty);
    });

    test('a row lock outside a transaction throws before any statement', () {
      expect(
        () => db().clubServices.find(lock: DwRowLock.forUpdate),
        throwsA(isA<StateError>()),
      );
      expect(
        () =>
            db().clubServices.findById(1, lock: DwRowLock.forUpdateSkipLocked),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('insertAll', () {
    test('returns the rows in input order with their ids', () async {
      final inserted = await db().clubServices.insertAll([
        for (var i = 0; i < 50; i++)
          service(
            title: 'S$i',
            price: i.isEven ? i.toDouble() : null,
            tags: i.isEven ? ['t$i'] : const [],
            archivedAt: i % 3 == 0 ? DateTime.utc(2026, 1, i + 1) : null,
            cover: i % 5 == 0 ? Uint8List.fromList([i]) : null,
          ),
      ]);
      expect(inserted.map((s) => s.title), [
        for (var i = 0; i < 50; i++) 'S$i',
      ]);
      expect(inserted.map((s) => s.id), [for (var i = 1; i <= 50; i++) i]);
      expect(inserted[2].tags, ['t2']);
      expect(inserted[1].price, isNull);
      expect(await db().clubServices.findById(inserted[3].id!), inserted[3]);
      final nulls = await db().query(
        'SELECT count(*) FILTER (WHERE price IS NULL) AS price, '
        'count(*) FILTER (WHERE archived_at IS NULL) AS archived, '
        'count(*) FILTER (WHERE cover IS NULL) AS cover FROM club_service',
      );
      expect(nulls.single, {'price': 25, 'archived': 33, 'cover': 40});
    });

    test('a null jsonb value is SQL NULL, not JSON null', () async {
      final yoga = await db().clubServices.insert(service());
      final sessions = await db().clubSessions.insertAll([
        for (var i = 0; i < 4; i++)
          ClubSessionRow(
            serviceId: yoga.id!,
            startsAt: DateTime.utc(2026, 1, i + 1),
            capacity: i,
            labels: i.isEven ? null : ['odd', '"$i"'],
          ),
      ]);
      expect(sessions.map((s) => s.labels), [
        null,
        ['odd', '"1"'],
        null,
        ['odd', '"3"'],
      ]);
      final single = await db().clubSessions.insert(
        sessions.first.copyWith(
          id: const DwFieldPatch.clear(),
          startsAt: DateTime.utc(2030),
        ),
      );
      expect(single.labels, isNull);
      final nulls = await db().query(
        'SELECT count(*) FILTER (WHERE labels IS NULL) AS n FROM club_session',
      );
      expect(nulls.single['n'], 3);
      expect(
        (await db().clubSessions.find(
          where: (t) => t.labels.inList([
            ['odd', '"3"'],
          ]),
        )).single.capacity,
        3,
      );
    });

    test('nullable columns in insertAll are SQL NULL', () async {
      final yoga = await db().clubServices.insert(service());
      await db().appSettings.insertAll([
        AppSettingRow(key: 'a', value: 'x', updatedAt: DateTime.utc(2026)),
        AppSettingRow(
          key: 'b',
          value: 'y',
          limits: {'n': 1},
          featuredServiceId: yoga.id,
          updatedAt: DateTime.utc(2026),
        ),
      ]);
      final raw = await db().query(
        'SELECT key, featured_service_id IS NULL AS no_feature, limits '
        'FROM app_setting ORDER BY key',
      );
      expect(raw.map((row) => row.get<bool>('no_feature')), [true, false]);
      expect(raw.map((row) => row['limits']), [
        {},
        {'n': 1},
      ]);
    });

    test('empty input sends nothing; mixed ids are refused', () async {
      expect(await db().clubServices.insertAll(const []), isEmpty);
      expect(
        () => db().clubServices.insertAll([
          service(),
          service().copyWith(id: const DwFieldPatch.set(7)),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('tryInsert', () {
    test('returns null when the unique key conflicts', () async {
      final setting = AppSettingRow(
        key: 'k',
        value: '1',
        updatedAt: DateTime.utc(2026),
      );
      final first = await db().appSettings.tryInsert(
        setting,
        onConflict: DwOnConflict.doNothing((t) => [t.key]),
      );
      expect(first, isNotNull);
      final second = await db().appSettings.tryInsert(
        setting.copyWith(value: '2'),
        onConflict: DwOnConflict.doNothing((t) => [t.key]),
      );
      expect(second, isNull);
      expect(
        (await db().appSettings.findFirst(
          where: (t) => t.key.equals('k'),
        ))!.value,
        '1',
      );
    });

    test('a multi-column unique index is a conflict target', () async {
      final yoga = await db().clubServices.insert(service());
      final session = ClubSessionRow(
        serviceId: yoga.id!,
        startsAt: DateTime.utc(2026, 10, 1, 9),
        capacity: 10,
      );
      final conflict = DwOnConflict<ClubSessionTable>.doNothing(
        (t) => [t.serviceId, t.startsAt],
      );
      expect(
        await db().clubSessions.tryInsert(session, onConflict: conflict),
        isNotNull,
      );
      expect(
        await db().clubSessions.tryInsert(session, onConflict: conflict),
        isNull,
      );
    });

    test(
      'an empty target accepts a conflict on any unique constraint',
      () async {
        final setting = AppSettingRow(
          key: 'k',
          value: '1',
          updatedAt: DateTime.utc(2026),
        );
        await db().appSettings.insert(setting);
        expect(
          await db().appSettings.tryInsert(
            setting,
            onConflict: DwOnConflict.doNothing((t) => const []),
          ),
          isNull,
        );
      },
    );
  });

  group('update and delete', () {
    test('update writes every column and returns the stored row', () async {
      final stored = await db().clubServices.insert(service(price: 5));
      final changed = stored.copyWith(
        title: 'Renamed',
        price: const DwFieldPatch.clear(),
        tags: ['x'],
        archivedAt: DwFieldPatch.set(DateTime.utc(2030)),
      );
      final updated = await db().clubServices.update(changed);
      expect(updated, changed);
      expect(await db().clubServices.findById(stored.id!), changed);
    });

    test('update of a missing row throws DwRowNotFound', () async {
      final ghost = service().copyWith(id: const DwFieldPatch.set(12345));
      await expectLater(
        db().clubServices.update(ghost),
        throwsA(
          isA<DwRowNotFound>()
              .having((e) => e.id, 'id', 12345)
              .having((e) => e.table, 'table', 'club_service'),
        ),
      );
      expect(() => db().clubServices.update(service()), throwsArgumentError);
    });

    test('updateWhere sets columns on matching rows', () async {
      await db().clubServices.insertAll([
        service(title: 'a', price: 1),
        service(title: 'b', price: 2),
        service(title: 'c'),
      ]);
      final count = await db().clubServices.updateWhere(
        where: (t) => t.price.isNotNull(),
        set: (t) => [t.price.set(null), t.kind.set(ClubServiceKind.personal)],
      );
      expect(count, 2);
      expect(
        await db().clubServices.count(
          where: (t) => t.kind.equals(ClubServiceKind.personal),
        ),
        2,
      );
      expect(
        () => db().clubServices.updateWhere(
          where: (t) => t.price.isNull(),
          set: (t) => const [],
        ),
        throwsArgumentError,
      );
    });

    test('delete and deleteWhere return affected counts', () async {
      final rows = await db().clubServices.insertAll([
        service(title: 'a'),
        service(title: 'b'),
        service(title: 'c'),
      ]);
      expect(await db().clubServices.delete(rows[0].id!), 1);
      expect(await db().clubServices.delete(rows[0].id!), 0);
      expect(
        await db().clubServices.deleteWhere(
          where: (t) => t.title.inList(['b', 'c']),
        ),
        2,
      );
    });

    test('a cascading reference deletes children; set null clears', () async {
      final yoga = await db().clubServices.insert(service());
      final first = await db().clubSessions.insert(
        ClubSessionRow(
          serviceId: yoga.id!,
          startsAt: DateTime.utc(2026),
          capacity: 1,
        ),
      );
      final other = await db().clubServices.insert(service(title: 'other'));
      final second = await db().clubSessions.insert(
        ClubSessionRow(
          serviceId: other.id!,
          previousSessionId: first.id,
          startsAt: DateTime.utc(2026),
          capacity: 1,
          note: 'follow-up',
        ),
      );
      await db().clubServices.delete(yoga.id!);
      expect(await db().clubSessions.findById(first.id!), isNull);
      final reloaded = await db().clubSessions.findById(second.id!);
      expect(reloaded!.previousSessionId, isNull);
      expect(reloaded.note, 'follow-up');
    });
  });

  group('errors', () {
    test('a unique violation names its constraint', () async {
      final setting = AppSettingRow(
        key: 'dup',
        value: '1',
        updatedAt: DateTime.utc(2026),
      );
      await db().appSettings.insert(setting);
      await expectLater(
        db().appSettings.insert(setting),
        throwsA(
          isA<DwUniqueViolation>()
              .having((e) => e.constraint, 'constraint', 'app_setting_key_key')
              .having((e) => e.code, 'code', '23505'),
        ),
      );
    });

    test('a foreign key violation names its constraint', () async {
      await expectLater(
        db().clubSessions.insert(
          ClubSessionRow(
            serviceId: 404,
            startsAt: DateTime.utc(2026),
            capacity: 1,
          ),
        ),
        throwsA(
          isA<DwForeignKeyViolation>().having(
            (e) => e.constraint,
            'constraint',
            'club_session_service_id_fkey',
          ),
        ),
      );
    });

    test('other server errors keep their SQLSTATE', () async {
      await expectLater(
        db().query('SELECT * FROM no_such_table'),
        throwsA(
          isA<DwDatabaseException>().having((e) => e.code, 'code', '42P01'),
        ),
      );
      await expectLater(
        db().execute("INSERT INTO app_setting (key) VALUES ('no value')"),
        throwsA(
          isA<DwDatabaseException>().having((e) => e.code, 'code', '23502'),
        ),
      );
    });
  });

  group('raw access', () {
    test('query binds named parameters and exposes typed getters', () async {
      await db().clubServices.insert(service(title: 'raw'));
      final rows = await db().query(
        'SELECT id, title, created_at FROM club_service WHERE title = @title',
        params: {'title': 'raw'},
      );
      expect(rows.single.get<String>('title'), 'raw');
      expect(rows.single.get<DateTime>('created_at').isUtc, isTrue);
      expect(rows.single['missing'], isNull);
      expect(
        () => rows.single.get<String>('id'),
        throwsA(isA<DwDecodeException>()),
      );
      expect(
        () => rows.single.get<int>('missing'),
        throwsA(isA<DwDecodeException>()),
      );
      expect(() => rows.single['id'] = 1, throwsUnsupportedError);
    });

    test('execute runs a script without parameters and counts rows', () async {
      final count = await db().execute('''
        INSERT INTO club_service (title, kind, duration, tags, offered_as, created_at) VALUES ('a', 'group', 1, '[]', '[]', now());
        INSERT INTO club_service (title, kind, duration, tags, offered_as, created_at) VALUES ('b', 'group', 1, '[]', '[]', now());
      ''');
      expect(count, 2);
      expect(
        await db().execute(
          'UPDATE club_service SET title = @title WHERE title = @old',
          params: {'title': 'c', 'old': 'a'},
        ),
        1,
      );
    });
  });

  test('schema of the generated tables', () {
    final session = fixtureSchema.table('club_session')!;
    expect(session.column('note_text')!.nullable, isTrue);
    expect(
      session.column('service_id')!.references,
      const DwForeignKey('club_service', onDelete: DwOnDelete.cascade),
    );
    expect(session.indexes.map((i) => i.name), [
      'club_session_service_id_starts_at_key',
      'club_session_starts_at_idx',
    ]);
    final setting = fixtureSchema.table('app_setting')!;
    expect(setting.column('featured_service_id')!.unique, isTrue);
    expect(setting.column('limits')!.sqlType, 'jsonb');
    expect(
      fixtureSchema.table('club_service')!.column('created_at')!.defaultSql,
      'now()',
    );
  });
}
