import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPlugin extends DwPlugin {
  bool initialized = false;
  DwFlutter? core;

  @override
  Future<void> init(DwFlutter core) async {
    this.core = core;
    initialized = true;
  }
}

class _UndeclaredPlugin extends DwPlugin {
  @override
  Future<void> init(DwFlutter core) async {}
}

/// A plugin the app declares through its interface while the object it actually
/// gets is a private implementation — exactly the shape of
/// `DwTelegramWebApp.create()`, which returns a web or stub impl. The registry
/// has to answer by the type the app asks for, not by the concrete class.
abstract class _Bridge extends DwPlugin {}

class _BridgeWebImpl extends _Bridge {
  @override
  Future<void> init(DwFlutter core) async {}
}

void main() {
  final recording = _RecordingPlugin();
  final bridge = _BridgeWebImpl();

  // One DwFlutter per test process — the singleton forbids re-creation.
  final dwInstance = DwFlutter(
    config: const DwConfig(),
    plugins: [recording, bridge],
  );

  group('plugin registry', () {
    test('resolves a declared plugin', () {
      expect(dwInstance.plugins.of<_RecordingPlugin>(), same(recording));
    });

    test('resolves an implementation through the interface the app names', () {
      expect(dwInstance.plugins.of<_Bridge>(), same(bridge));
    });

    test('an undeclared plugin fails with a message that says what to do', () {
      expect(
        () => dwInstance.plugins.of<_UndeclaredPlugin>(),
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

    // The whole reason `init` takes an argument: a plugin is constructed as an
    // argument to the constructor that assigns `dw`, so reading the ambient
    // instance from inside `plugins: [...]` throws LateInitializationError.
    // `init` is the first moment the core exists, and it is handed over rather
    // than looked up.
    test('a plugin is handed the core it was plugged into', () async {
      await dwInstance.init();

      expect(recording.core, same(dwInstance));
    });
  });
}
