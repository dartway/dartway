import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Theme { system, dark }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DwSharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = DwSharedPreferences();
    await prefs.init();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('provider returns the default, then reflects and persists an update',
      () async {
    final darkMode = prefs.provider<bool>(key: 'darkMode', defaultValue: false);

    expect(container.read(darkMode), isFalse);

    await container.read(darkMode.notifier).update(true);

    expect(container.read(darkMode), isTrue);
    expect(prefs.raw.getBool('darkMode'), isTrue);
  });

  test('provider throws UnsupportedError for a type SharedPreferences cannot store',
      () async {
    final when =
        prefs.provider<DateTime>(key: 'when', defaultValue: DateTime(2020));

    // Reading the default is fine; only the write hits the type dispatch.
    expect(container.read(when), DateTime(2020));

    await expectLater(
      container.read(when.notifier).update(DateTime(2021)),
      throwsA(isA<UnsupportedError>()),
    );
  });

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
}
