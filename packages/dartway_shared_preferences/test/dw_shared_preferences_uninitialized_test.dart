// Regression coverage for dartway/dartway#363: a provider read before any
// `DwSharedPreferences` has finished `init()` must fail with a `StateError`
// that names the cause, not a `LateInitializationError` pointing at a private
// field the caller never touched directly.
//
// No `DwSharedPreferences.init()` runs anywhere in this file — that is the
// whole point, so this stays true regardless of what other test files do
// (each runs in its own isolate) and regardless of test order within this
// file (there is only one test).
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';

final _neverInitedPlugin = DwSharedPreferences();

final _tooEarlyProvider = _neverInitedPlugin.provider<bool>(
  key: 'darkMode',
  defaultValue: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reading a provider before any DwSharedPreferences finished init() '
    'throws a StateError naming dw.init(), not a LateInitializationError',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(_tooEarlyProvider),
        // Riverpod wraps a notifier's `build()` exception in a
        // `ProviderException` — the `StateError` the fix throws is its
        // `.exception`.
        throwsA(
          isA<ProviderException>()
              .having((e) => e.exception, 'exception', isA<StateError>())
              .having((e) => '${e.exception}', 'message', contains('dw.init()')),
        ),
      );
    },
  );
}
