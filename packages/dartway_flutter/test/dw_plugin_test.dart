import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPlugin extends DwPlugin {
  bool initialized = false;

  @override
  Future<void> init() async => initialized = true;
}

class _UndeclaredPlugin extends DwPlugin {
  @override
  Future<void> init() async {}
}

/// A plugin the app declares through its interface while the object it actually
/// gets is a private implementation — exactly the shape of
/// `DwTelegramWebApp.create()`, which returns a web or stub impl. The registry
/// has to answer by the type the app asks for, not by the concrete class.
abstract class _Bridge extends DwPlugin {}

class _BridgeWebImpl extends _Bridge {
  @override
  Future<void> init() async {}
}

void main() {
  final recording = _RecordingPlugin();
  final bridge = _BridgeWebImpl();

  // One DwFlutter per test process — the singleton forbids re-creation.
  final dwInstance = DwFlutter(
    config: const DwConfig(useSharedPreferences: false),
    plugins: [recording, bridge],
  );

  group('plugin registry', () {
    test('resolves a declared plugin', () {
      expect(dwInstance.plugin<_RecordingPlugin>(), same(recording));
    });

    test('resolves an implementation through the interface the app names', () {
      expect(dwInstance.plugin<_Bridge>(), same(bridge));
    });

    test('an undeclared plugin fails with a message that says what to do', () {
      expect(
        () => dwInstance.plugin<_UndeclaredPlugin>(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('_UndeclaredPlugin'), contains('plugins:')),
          ),
        ),
      );
    });

    test('every plugin is initialized with the app core', () async {
      expect(recording.initialized, isFalse);

      await dwInstance.init();

      expect(recording.initialized, isTrue);
    });
  });
}
