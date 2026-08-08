// The point of this file is its import list: **only this package**, no riverpod.
//
// A consumer declares a preference provider as a top-level `final`, which is
// what the plugin asks for. Before `DwPrefProvider` existed the type of that
// `final` was `NotifierProvider<PrefNotifier<T>, T>` — nameable only where
// riverpod is imported, which a file that just wants to remember a setting has
// no other reason to do. And the failure did not say so: the analyzer reported
// *"the getter 'prefs' isn't defined for the type DwPlugins"*, pointing at a
// getter that is perfectly fine, while `unused_import` suggested removing the
// import that fixed it.
//
// So this test is not about behaviour. If it compiles, a consumer needs nothing
// but this package — and if somebody widens a signature back to a raw riverpod
// type, it stops compiling.

import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Theme { system, dark }

late DwSharedPreferences _prefs;

/// Declared the way the README tells a project to declare one: a top-level
/// `final` with the type written out, in a library that knows nothing of
/// riverpod.
late final DwPrefProvider<bool> darkModeProvider = _prefs.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);

late final DwMappedPrefProvider<_Theme> themeProvider = _prefs
    .mappedProvider<_Theme>(
      key: 'theme',
      mapFrom: (stored) => _Theme.values.asNameMap()[stored ?? ''] ?? _Theme.system,
      mapTo: (theme) => theme.name,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a consumer declares both providers importing only this package', () async {
    SharedPreferences.setMockInitialValues({});
    _prefs = DwSharedPreferences();
    await _prefs.init();

    // Reading them is enough: the assertion this file makes is that the two
    // declarations above compile at all.
    expect(darkModeProvider, isNotNull);
    expect(themeProvider, isNotNull);
  });
}
