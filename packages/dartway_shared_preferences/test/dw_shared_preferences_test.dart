import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Theme { system, dark }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DwSharedPreferences prefs;
  late ProviderContainer container;

  // `init` takes the core the plugin was plugged into, so a test that inits the
  // plugin by hand needs one to hand over. Built once — one DwFlutter per test
  // process — and reused: local storage reads nothing out of it.
  final dwInstance = DwFlutter(config: const DwConfig());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = DwSharedPreferences();
    await prefs.init(dwInstance);
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test(
    'provider returns the default, then reflects and persists an update',
    () async {
      final darkMode = prefs.provider<bool>(
        key: 'darkMode',
        defaultValue: false,
      );

      expect(container.read(darkMode), isFalse);

      await container.read(darkMode.notifier).update(true);

      expect(container.read(darkMode), isTrue);
      expect(prefs.raw.getBool('darkMode'), isTrue);
    },
  );

  test(
    'provider throws UnsupportedError for a type SharedPreferences cannot store',
    () async {
      final when = prefs.provider<DateTime>(
        key: 'when',
        defaultValue: DateTime(2020),
      );

      // Reading the default is fine; only the write hits the type dispatch.
      expect(container.read(when), DateTime(2020));

      await expectLater(
        container.read(when.notifier).update(DateTime(2021)),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );

  test('mappedProvider round-trips a custom type through a String', () async {
    final theme = prefs.mappedProvider<_Theme>(
      key: 'theme',
      mapFrom: (raw) => _Theme.values.byName(raw ?? 'system'),
      mapTo: (mode) => mode.name,
    );

    expect(container.read(theme), _Theme.system);

    await container.read(theme.notifier).update(_Theme.dark);

    expect(container.read(theme), _Theme.dark);
    expect(prefs.raw.getString('theme'), 'dark');
  });

  group('providerFamily', () {
    test('two arguments keep separate values under separate keys', () async {
      final sort = prefs.providerFamily<String, int>(
        keyFor: (projectId) => 'project.$projectId.sort',
        defaultValue: 'name',
      );

      await container.read(sort(1).notifier).update('createdAt');

      expect(container.read(sort(1)), 'createdAt');
      // The other project never heard about it — this is the whole point.
      expect(container.read(sort(2)), 'name');

      expect(prefs.raw.getString('project.1.sort'), 'createdAt');
      expect(prefs.raw.getString('project.2.sort'), isNull);
    });

    test(
      'the same argument resolves to one provider, shared by every reader',
      () async {
        final sort = prefs.providerFamily<String, int>(
          keyFor: (projectId) => 'project.$projectId.sort',
          defaultValue: 'name',
        );

        // Two separate calls with the same argument. Riverpod compares family
        // providers by (family, argument), so the container holds one state
        // behind both — the guarantee a loop over `provider` cannot give.
        expect(sort(7), sort(7));
        expect(
          container.read(sort(7).notifier),
          same(container.read(sort(7).notifier)),
        );

        await container.read(sort(7).notifier).update('createdAt');

        // A second reader that resolved the family independently sees the write.
        expect(container.read(sort(7)), 'createdAt');
      },
    );

    test('reads a value already in storage instead of the default', () async {
      SharedPreferences.setMockInitialValues({'project.3.sort': 'createdAt'});
      prefs = DwSharedPreferences();
      await prefs.init(dwInstance);

      final sort = prefs.providerFamily<String, int>(
        keyFor: (projectId) => 'project.$projectId.sort',
        defaultValue: 'name',
      );

      expect(container.read(sort(3)), 'createdAt');
      expect(container.read(sort(4)), 'name');
    });
  });

  group('mappedProviderFamily', () {
    test('two arguments keep separate values under separate keys', () async {
      final theme = prefs.mappedProviderFamily<_Theme, String>(
        keyFor: (section) => 'section.$section.theme',
        mapFrom: (raw) => _Theme.values.byName(raw ?? 'system'),
        mapTo: (mode) => mode.name,
      );

      await container.read(theme('billing').notifier).update(_Theme.dark);

      expect(container.read(theme('billing')), _Theme.dark);
      expect(container.read(theme('reports')), _Theme.system);

      expect(prefs.raw.getString('section.billing.theme'), 'dark');
      expect(prefs.raw.getString('section.reports.theme'), isNull);
    });

    test(
      'the same argument resolves to one provider, shared by every reader',
      () async {
        final theme = prefs.mappedProviderFamily<_Theme, String>(
          keyFor: (section) => 'section.$section.theme',
          mapFrom: (raw) => _Theme.values.byName(raw ?? 'system'),
          mapTo: (mode) => mode.name,
        );

        expect(theme('billing'), theme('billing'));
        expect(
          container.read(theme('billing').notifier),
          same(container.read(theme('billing').notifier)),
        );

        await container.read(theme('billing').notifier).update(_Theme.dark);

        expect(container.read(theme('billing')), _Theme.dark);
      },
    );
  });
}
