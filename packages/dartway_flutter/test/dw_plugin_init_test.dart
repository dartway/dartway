import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plugin whose `init` throws. [blocksStartup] is the whole variable.
class _FailingPlugin extends DwPlugin {
  _FailingPlugin({bool? blocking}) : _blocking = blocking;

  final bool? _blocking;

  /// Unset means the plugin says nothing — the default is what is under test.
  @override
  bool get blocksStartup => _blocking ?? super.blocksStartup;

  @override
  Future<void> init(DwFlutter core) async {
    throw StateError('no localStorage');
  }
}

/// Declared after the failing one. Whether it ran is the blast radius.
class _LaterPlugin extends DwPlugin {
  bool initialized = false;

  @override
  Future<void> init(DwFlutter core) async {
    initialized = true;
  }
}

void main() {
  final reports = <DwErrorReport>[];

  // One core per process; the registries under test are built separately.
  final core = DwFlutter(
    config: DwConfig(onErrorReport: reports.add),
    plugins: const [],
  );

  setUp(reports.clear);

  group('a plugin that blocks startup', () {
    test('is the default, said by nobody', () {
      expect(_FailingPlugin().blocksStartup, isTrue);
    });

    test('stops the start and the failure names it', () async {
      final later = _LaterPlugin();

      await expectLater(
        DwPlugins([_FailingPlugin(), later]).initAll(core),
        throwsA(
          isA<DwPluginInitException>()
              .having((e) => e.plugin, 'plugin', _FailingPlugin)
              .having((e) => '$e', 'text', contains('no localStorage')),
        ),
      );

      // Unchanged from before the fix, and deliberately: a plugin the app
      // expects to have is not something to start without.
      expect(later.initialized, isFalse);
    });

    test('is reported once, by whoever catches it — not here as well', () async {
      await DwPlugins([
        _FailingPlugin(),
      ]).initAll(core).catchError((Object _) {});

      expect(reports, isEmpty);
    });
  });

  group('a plugin that does not block startup', () {
    test('costs its own feature and nothing else', () async {
      final later = _LaterPlugin();

      await DwPlugins([
        _FailingPlugin(blocking: false),
        later,
      ]).initAll(core);

      expect(later.initialized, isTrue);
    });

    test('is reported through the pipeline, naming the plugin', () async {
      await DwPlugins([_FailingPlugin(blocking: false)]).initAll(core);

      expect(reports, hasLength(1));
      expect('${reports.single.error}', contains('_FailingPlugin'));
      expect('${reports.single.error}', contains('no localStorage'));
    });

    test('reaching for it says what happened, not a late-init error', () async {
      // The failure mode being replaced: a swallowed init leaves `late final`
      // fields unset, and the app dies at the first touch on a
      // LateInitializationError from inside the package — further from the
      // cause than the crash it replaced.
      final plugins = DwPlugins([_FailingPlugin(blocking: false)]);
      await plugins.initAll(core);

      expect(
        plugins.of<_FailingPlugin>,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('_FailingPlugin'),
              contains('no localStorage'),
              contains('blocksStartup'),
            ),
          ),
        ),
      );
    });

    test('does not hold its role: maybeOf answers that nobody took it', () async {
      // The framework asking whether anybody took a job gets the honest
      // answer. The failure was already reported at init, so this is not a
      // silence — it is the degradation the app asked for.
      final plugins = DwPlugins([_FailingPlugin(blocking: false)]);
      await plugins.initAll(core);

      expect(plugins.maybeOf<_FailingPlugin>(), isNull);
    });
  });
}
