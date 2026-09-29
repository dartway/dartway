import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Seeds are startup steps that converge on the declaration at every start;
/// settings are one value per data object, read with its defaults and written
/// without a lock of the project's own (#388, #394).
void main() {
  group('DwSeedRows', () {
    late DwTestDatabase database;
    late TestApp app;

    setUp(() async {
      app = TestApp();
      RecordingLogger.lines.clear();
      database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'server_test',
      );
    });
    tearDown(() => database.drop());

    /// Starts the server with [catalogue] seeded, runs [body], stops it.
    Future<T> started<T>(
      List<CatalogItemRow> catalogue,
      Future<T> Function(DwTestServer server) body,
    ) async {
      final base = app.server(database.config);
      final server = await DwTestServer.start(
        DwAppServer(
          protocol: base.protocol,
          migrations: [...base.migrations, const _CatalogMigration()],
          database: database.config,
          auth: base.auth,
          alerts: base.alerts,
          logger: base.logger,
          settings: base.settings,
          features: [
            ...base.features,
            DwServerFeature(
              'catalog',
              startup: [
                DwSeedRows(
                  'catalog',
                  table: (db) => db.catalogItems,
                  key: (t) => [t.slug],
                  rows: catalogue,
                ),
              ],
            ),
          ],
        ),
      );
      try {
        return await body(server);
      } finally {
        await server.stop();
      }
    }

    Future<Map<String, (int, String, bool)>> stored(
      DwTestServer server,
    ) async => {
      for (final row in await server.db.catalogItems.find())
        row.slug: (row.id!, row.title, row.published),
    };

    Future<Map<String, String>> versions(DwTestServer server) async => {
      for (final row in await server.db.query(
        'SELECT slug, xmin::text AS version FROM catalog_item',
      ))
        row.get<String>('slug'): row.get<String>('version'),
    };

    List<String> seedLines() => [
      for (final line in RecordingLogger.lines)
        if (line.contains('seed catalog')) line,
    ];

    const yoga = CatalogItemRow(slug: 'yoga', title: 'Yoga');
    const boxing = CatalogItemRow(slug: 'boxing', title: 'Boxing');

    test('the first start inserts the declared rows', () async {
      final rows = await started([yoga, boxing], stored);
      expect(rows.keys, unorderedEquals(['yoga', 'boxing']));
      expect(rows['yoga']!.$2, 'Yoga');
      expect(seedLines().single, contains('2 of 2 rows written'));
    });

    test('a start with nothing new writes nothing', () async {
      final first = await started([yoga, boxing], versions);
      RecordingLogger.lines.clear();
      final second = await started([yoga, boxing], versions);
      expect(second, first, reason: 'no row was rewritten');
      expect(
        seedLines(),
        isEmpty,
        reason: 'a step that changed nothing is quiet',
      );
    });

    test(
      'an edited declaration reaches the stored row, keeping its id',
      () async {
        final before = await started([yoga, boxing], stored);
        RecordingLogger.lines.clear();
        final after = await started([
          yoga.copyWith(title: 'Hatha yoga'),
          boxing,
          const CatalogItemRow(slug: 'swim', title: 'Swim'),
        ], stored);
        expect(after['yoga'], (before['yoga']!.$1, 'Hatha yoga', true));
        expect(after['boxing'], before['boxing']);
        expect(after.keys, contains('swim'));
        expect(seedLines().single, contains('2 of 3 rows written'));
      },
    );

    test('a row the declaration no longer names is left alone', () async {
      await started([yoga, boxing], stored);
      final after = await started([
        yoga,
        boxing.copyWith(published: false),
      ], stored);
      expect(after['boxing']!.$3, isFalse, reason: 'retired by a column');
      final dropped = await started([yoga], stored);
      expect(dropped.keys, unorderedEquals(['yoga', 'boxing']));
    });

    test('a declaration naming one key twice stops the start', () async {
      await expectLater(
        started([yoga, yoga.copyWith(title: 'Twice')], stored),
        throwsA(anything),
      );
      expect(
        RecordingLogger.lines,
        contains(contains('startup step "catalog" failed')),
      );
    });
  });

  group('ctx.settings', () {
    final harness = useHarness(
      build: (app, config) {
        final base = app.server(config);
        return DwAppServer(
          protocol: DwWireProtocol([
            DwProtocolEntry<ClubSettings>(
              'ClubSettings',
              ClubSettings.fromJson,
            ),
            DwProtocolEntry<StrictSettings>(
              'StrictSettings',
              StrictSettings.fromJson,
            ),
          ], include: testProtocol),
          migrations: base.migrations,
          database: config,
          auth: base.auth,
          alerts: base.alerts,
          logger: base.logger,
          settings: base.settings,
          features: base.features,
        );
      },
    );

    setUp(() => harness().db.execute('DELETE FROM dw_setting'));

    Future<T> inContext<T>(Future<T> Function(DwCallContext ctx) work) =>
        harness().server.runInContext(work);

    Future<List<Map<String, Object?>>> rows() async => [
      for (final row in await harness().db.query(
        'SELECT area, value FROM dw_setting ORDER BY area',
      ))
        {'area': row['area'], 'value': row['value']},
    ];

    test('read answers the defaults while nothing is stored', () async {
      final settings = await inContext(
        (ctx) => ctx.settings.read<ClubSettings>(),
      );
      expect(settings, const ClubSettings());
      expect(await rows(), isEmpty, reason: 'a read writes nothing');
    });

    test('save stores only what differs from the defaults', () async {
      await inContext(
        (ctx) => ctx.settings.save(const ClubSettings(name: 'Acme')),
      );
      expect(await rows(), [
        {
          'area': 'ClubSettings',
          'value': {'name': 'Acme'},
        },
      ]);
      expect(
        await inContext((ctx) => ctx.settings.read<ClubSettings>()),
        const ClubSettings(name: 'Acme'),
      );
    });

    test('concurrent first saves all succeed and leave one row', () async {
      final saved = await Future.wait([
        for (var i = 0; i < 8; i++)
          inContext((ctx) => ctx.settings.save(ClubSettings(name: 'Club $i'))),
      ]);
      expect(saved, hasLength(8));
      expect(await rows(), hasLength(1));
    });

    test('concurrent updates of different fields both land', () async {
      await Future.wait([
        for (var i = 0; i < 4; i++) ...[
          inContext(
            (ctx) => ctx.settings.update<ClubSettings>(
              (current) => current.copyWith(name: 'Renamed'),
            ),
          ),
          inContext(
            (ctx) => ctx.settings.update<ClubSettings>(
              (current) => current.copyWith(signUpOpen: false),
            ),
          ),
        ],
      ]);
      expect(
        await inContext((ctx) => ctx.settings.read<ClubSettings>()),
        const ClubSettings(name: 'Renamed', signUpOpen: false),
      );
    });

    test('an update that changes nothing writes nothing', () async {
      await inContext(
        (ctx) => ctx.settings.save(const ClubSettings(name: 'Acme')),
      );
      Future<String> version() async => (await harness().db.query(
        'SELECT xmin::text AS version FROM dw_setting',
      )).single.get<String>('version');
      final before = await version();
      final answered = await inContext(
        (ctx) => ctx.settings.update<ClubSettings>(
          (current) => current.copyWith(name: 'Acme'),
        ),
      );
      expect(answered, const ClubSettings(name: 'Acme'));
      expect(await version(), before);
    });

    test('a type outside the protocol is refused by name', () async {
      await expectLater(
        inContext((ctx) => ctx.settings.read<UnregisteredSettings>()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('not a data object of this server'),
          ),
        ),
      );
    });

    test('a settings object without a default for a field says so', () async {
      await expectLater(
        inContext((ctx) => ctx.settings.read<StrictSettings>()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('every field of a settings object needs a default'),
          ),
        ),
      );
    });
  });
}

/// A settings object: every field defaulted, a fixed id. Hand-written in the
/// shape `dartway generate` gives a data object.
final class ClubSettings extends DwDataObject {
  const ClubSettings({this.name = 'Club', this.signUpOpen = true});

  @override
  String get id => 'club';

  final String name;
  final bool signUpOpen;

  ClubSettings copyWith({String? name, bool? signUpOpen}) => ClubSettings(
    name: name ?? this.name,
    signUpOpen: signUpOpen ?? this.signUpOpen,
  );

  @override
  String get dwTypeName => 'ClubSettings';

  @override
  Map<String, Object?> toJson() => {
    if (name != 'Club') 'name': name,
    if (!signUpOpen) 'signUpOpen': signUpOpen,
  };

  static ClubSettings fromJson(Map<String, Object?> json) => ClubSettings(
    name: json['name'] == null ? 'Club' : json['name']! as String,
    signUpOpen: json['signUpOpen'] == null ? true : json['signUpOpen']! as bool,
  );

  @override
  bool operator ==(Object other) =>
      other is ClubSettings &&
      other.name == name &&
      other.signUpOpen == signUpOpen;

  @override
  int get hashCode => Object.hash(name, signUpOpen);

  @override
  String toString() => 'ClubSettings(name: $name, signUpOpen: $signUpOpen)';
}

/// A field without a default: not something a settings object may have.
final class StrictSettings extends DwDataObject {
  const StrictSettings({required this.name});

  @override
  String get id => 'strict';

  final String name;

  @override
  String get dwTypeName => 'StrictSettings';

  @override
  Map<String, Object?> toJson() => {'name': name};

  static StrictSettings fromJson(Map<String, Object?> json) =>
      StrictSettings(name: json['name']! as String);
}

final class UnregisteredSettings extends DwDataObject {
  const UnregisteredSettings();

  @override
  String get id => 'unregistered';

  @override
  String get dwTypeName => 'UnregisteredSettings';

  @override
  Map<String, Object?> toJson() => const {};
}

/// A row seeded by [DwSeedRows], hand-written in the shape `dartway generate`
/// produces.
final class CatalogItemRow extends DwTableRow {
  const CatalogItemRow({
    this.id,
    required this.slug,
    required this.title,
    this.published = true,
  });

  @override
  final int? id;
  final String slug;
  final String title;
  final bool published;

  CatalogItemRow copyWith({String? title, bool? published}) => CatalogItemRow(
    id: id,
    slug: slug,
    title: title ?? this.title,
    published: published ?? this.published,
  );

  static const tableDef = CatalogItemTable();
}

final class CatalogItemTable extends DwTableDef<CatalogItemRow> {
  const CatalogItemTable() : super('catalog_item');

  DwTableColumn<String> get slug =>
      const DwTableColumn('slug', DwColumnType.text, unique: true);

  DwTableColumn<String> get title =>
      const DwTableColumn('title', DwColumnType.text);

  DwTableColumn<bool> get published =>
      const DwTableColumn('published', DwColumnType.boolean);

  @override
  List<DwTableColumn<Object?>> get tableColumns => [id, slug, title, published];

  @override
  CatalogItemRow fromRow(DwResultRow row) => CatalogItemRow(
    id: row.decode(id),
    slug: row.decode(slug),
    title: row.decode(title),
    published: row.decode(published),
  );

  @override
  Map<String, Object?> toRow(CatalogItemRow row) => {
    if (row.id != null) 'id': row.id,
    'slug': row.slug,
    'title': row.title,
    'published': row.published,
  };
}

final class _CatalogMigration extends DwDatabaseMigration {
  const _CatalogMigration();

  @override
  String get id => '20260930_120000_catalog';

  @override
  String get checksum => 'catalog-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql(
    'CREATE TABLE catalog_item (id bigserial PRIMARY KEY, '
    'slug text NOT NULL UNIQUE, title text NOT NULL, '
    'published boolean NOT NULL)',
  );
}

extension on DwDatabaseHandle {
  DwTableRepository<CatalogItemRow, CatalogItemTable> get catalogItems =>
      repository(CatalogItemRow.tableDef);
}
