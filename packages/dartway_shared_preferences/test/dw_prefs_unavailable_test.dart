import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// A platform store that refuses to open, the way a browser with no local
/// storage does: `shared_preferences_web` reads a null there and dies inside
/// the package, so what reaches Dart names neither storage nor the plugin.
class _RefusingStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => throw StateError('no localStorage');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw StateError('no localStorage');

  @override
  Future<bool> remove(String key) async => throw StateError('no localStorage');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw StateError('no localStorage');

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async =>
      throw StateError('no localStorage');

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async => throw StateError('no localStorage');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reports = <DwErrorReport>[];
  final core = DwFlutter(
    config: DwConfig(onErrorReport: reports.add),
    plugins: const [],
  );

  setUp(() {
    reports.clear();
    // `SharedPreferences.getInstance` caches a successful load for the life of
    // the process, so without this the first test's fallback would answer for
    // every test after it and they would all pass for the wrong reason.
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _RefusingStore();
  });

  group('a platform with no store', () {
    test('by default the app runs and says it is not remembering', () async {
      final prefs = DwSharedPreferences();

      await prefs.init(core);

      expect(prefs.isPersistent, isFalse);
      // Usable, which is the point: every call site would otherwise meet a
      // LateInitializationError on `raw`.
      await prefs.setString('k', 'v');
      expect(await prefs.getString('k'), 'v');
    });

    test('the fallback is reported once, not per read', () async {
      final prefs = DwSharedPreferences();

      await prefs.init(core);
      await prefs.setString('k', 'v');
      await prefs.getString('k');

      expect(reports, hasLength(1));
      expect('${reports.single.error}', contains('only as long as this tab'));
    });

    test('an app that would rather not run says so, and the failure is let out',
        () async {
      // With blocksStartup at its default this stops the start — the right
      // answer where a session that cannot survive a reload is worse than no
      // app at all.
      final prefs = DwSharedPreferences(
        whenUnavailable: DwPrefsUnavailable.fail,
      );

      await expectLater(prefs.init(core), throwsA(isA<StateError>()));
      expect(prefs.blocksStartup, isTrue);
    });
  });

  group('a working platform', () {
    setUp(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance =
          InMemorySharedPreferencesStore.empty();
    });

    test('is persistent as far as the plugin is concerned', () async {
      final prefs = DwSharedPreferences();

      await prefs.init(core);

      expect(prefs.isPersistent, isTrue);
      expect(reports, isEmpty);
    });

    test('claims the key-value role the core asks for', () async {
      // The core reaches for the role, not for this class: that is what lets
      // it keep no storage package of its own.
      expect(DwSharedPreferences(), isA<DwKeyValueStorePlugin>());
    });
  });
}
