// Regression coverage for dartway/dartway#363: a provider must not bind to
// the `DwSharedPreferences` instance `.provider()`/`.mappedProvider()`/
// `.providerFamily()`/`.mappedProviderFamily()` was called on. It has to
// resolve the store fresh, per `ProviderContainer`, from whichever plugin
// most recently finished `init()` — otherwise the first core to touch the
// provider in the isolate binds it forever, and every later core (a fresh one
// per widget test, in the real failure) reads and writes through that first
// core's stale store instead of its own.
//
// Every provider below is a genuine top-level `final`, exactly the shape the
// class doc in `dw_shared_preferences.dart` tells a project to use — that
// shape only breaks because `flutter test` runs every test in one file inside
// one isolate, and a top-level `final`'s initializer runs exactly once, on
// first access, for the life of that isolate. `_prefs` stands in for the
// mutable `dw` a real app reassigns per `AppDwCore.create()`/
// `DwFlutterToolbox()`; each test below rebinds it before touching its
// provider, the way a widget test rebinds `dw` before pumping its widget.
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Theme { system, dark }

late DwSharedPreferences _prefs;

final _darkModeProvider = _prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);

final _themeProvider = _prefs.mappedProvider<_Theme>(
  key: 'theme',
  mapFrom: (raw) => _Theme.values.byName(raw ?? 'system'),
  mapTo: (mode) => mode.name,
);

final _sortProvider = _prefs.providerFamily<String, int>(
  keyFor: (projectId) => 'project.$projectId.sort',
  defaultValue: 'name',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One `DwFlutterToolbox` handed to every `init()` call below — `init` only
  // reads it for `core.handleError`, which the success path never reaches.
  final dwInstance = DwFlutterToolbox(config: const DwFlutterConfig());

  Future<DwSharedPreferences> newCore(Map<String, Object> seed) async {
    // A fresh `SharedPreferences` snapshot and a fresh plugin instance — the
    // same two things a widget test's helper builds per test.
    SharedPreferences.setMockInitialValues(seed);
    final plugin = DwSharedPreferences();
    await plugin.init(dwInstance);
    return plugin;
  }

  test(
    'provider: a second core/container pair reads and writes its own store, '
    'not the first core that touched the top-level provider',
    () async {
      final coreA = await newCore({'darkMode': true});
      _prefs = coreA;
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);

      // First access in the isolate: this is what evaluates the top-level
      // `final` and, pre-fix, bound it to `coreA` forever.
      expect(containerA.read(_darkModeProvider), isTrue);

      final coreB = await newCore({'darkMode': false});
      _prefs = coreB;
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);

      // Same top-level provider, a different container, a different core's
      // seed. Pre-fix this reads `coreA`'s stale `true` instead.
      expect(containerB.read(_darkModeProvider), isFalse);

      // A write through container #2 lands in core B's store...
      await containerB.read(_darkModeProvider.notifier).update(true);
      expect(coreB.raw.getBool('darkMode'), isTrue);
      // ...and never reaches core A's, which nothing here touched again.
      expect(coreA.raw.getBool('darkMode'), isTrue);
    },
  );

  test(
    'mappedProvider: same guarantee, round-tripped through a String',
    () async {
      final coreA = await newCore({'theme': 'dark'});
      _prefs = coreA;
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);

      expect(containerA.read(_themeProvider), _Theme.dark);

      final coreB = await newCore({}); // no seed: falls back to `system`
      _prefs = coreB;
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);

      // Pre-fix this reads core A's stale `dark` instead of core B's default.
      expect(containerB.read(_themeProvider), _Theme.system);

      await containerB.read(_themeProvider.notifier).update(_Theme.dark);
      expect(coreB.raw.getString('theme'), 'dark');
      // Core A's own store is untouched by container B's write.
      expect(coreA.raw.getString('theme'), 'dark');
    },
  );

  test(
    'providerFamily: same guarantee, per argument',
    () async {
      final coreA = await newCore({'project.1.sort': 'createdAt'});
      _prefs = coreA;
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);

      expect(containerA.read(_sortProvider(1)), 'createdAt');

      final coreB = await newCore({}); // fresh store: falls back to default
      _prefs = coreB;
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);

      // Pre-fix this reads core A's stale `createdAt` instead of the default.
      expect(containerB.read(_sortProvider(1)), 'name');

      await containerB.read(_sortProvider(1).notifier).update('createdAt');
      expect(coreB.raw.getString('project.1.sort'), 'createdAt');
      // Core A's own store never saw container B's write.
      expect(coreA.raw.getString('project.1.sort'), 'createdAt');
    },
  );
}
