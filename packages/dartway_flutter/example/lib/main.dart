// A runnable tour of dartway_flutter. Copy the folder, `flutter run`, and read
// this file top to bottom — each section demonstrates one feature of the
// skeleton, in the order an app meets them.
//
// It depends on nothing but dartway_flutter: no server, no data layer. The
// async examples use a fake `Future`; in a real app the same widgets render a
// live list from the DartWay data layer.

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// The ambient core. An app declares `dw` itself — the package hands you no
// global. Declared here, reachable from anywhere as `dw` after this line runs.
// ---------------------------------------------------------------------------
late final DwFlutter dw;

// ---------------------------------------------------------------------------
// 1. Bootstrap. `DwAppRunner` owns what every app sets up and none enjoys
//    setting up: ProviderScope, the native splash, ordered initializers, and a
//    zone that routes uncaught errors into the error pipeline.
// ---------------------------------------------------------------------------
void main() {
  dw = DwFlutter(
    config: DwConfig(
      appVersion: '1.0.0',
      // One error hook, rich by default: it receives the app-state snapshot,
      // not a bare stack trace. Here we just print it.
      onErrorReport: (report) => debugPrint(
        'Reported: ${report.error} '
        '(source: ${report.source.name}, route: ${report.context.route})',
      ),
    ),
    // Plugins are the seam for optional integrations. Declared here, reached
    // anywhere via `dw.plugins.of<T>()` (or a named accessor a plugin package
    // adds, like `dw.plugins.telegram`). This one is a toy declared below.
    plugins: [_ClockPlugin()],
  );

  // Lazy context sources are pulled into every error report. Register the route
  // once at startup; a real app feeds this from its router. Without it,
  // report.context.route is null — which is exactly what makes the report dull.
  dw.errorContext.registerRouteSource(() => '/tour');

  DwAppRunner(
    supportedLocales: const [Locale('en')],
    child: const _ExampleApp(),
  ).run();
}

/// A toy plugin, so the plugins section has something real to resolve. A real
/// plugin (Telegram, prefs) is the same shape: implement DwPlugin, get
/// initialized with the app, be reached through dw.plugins.
class _ClockPlugin extends DwPlugin {
  late final DateTime startedAt;

  @override
  Future<void> init() async => startedAt = DateTime.now();
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dartway_flutter tour',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      // -----------------------------------------------------------------------
      // 2. Notifications. Mount one listener with a handler per notification
      //    type; then post from anywhere with `dw.notify.*`.
      // -----------------------------------------------------------------------
      builder: (context, child) => DwNotificationsListener(
        handlers: {DwUiNotification: DwUiNotificationHandler()},
        child: child!,
      ),
      home: const _TourScreen(),
    );
  }
}

// Fake async sources, so the async-UI sections have something to render. In a
// real app these are providers from the DartWay data layer.
final _greetingProvider = FutureProvider<String>((ref) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  return 'Loaded from an async source';
});

final _itemsProvider = FutureProvider<List<String>>((ref) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  return ['First item', 'Second item', 'Third item'];
});

class _TourScreen extends ConsumerWidget {
  const _TourScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('dartway_flutter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------------------------------------------------------------------
          // 3. Notifications, posted. `dw.notify.success/error/...` delivers a
          //    toast through the pipeline mounted above.
          // -------------------------------------------------------------------
          _Section('Notifications', [
            FilledButton(
              onPressed: () => dw.notify.success('Saved'),
              child: const Text('Notify success'),
            ),
            FilledButton.tonal(
              onPressed: () => dw.notify.error('Could not reach the server'),
              child: const Text('Notify error'),
            ),
          ]),

          // -------------------------------------------------------------------
          // 4. Guarded actions. `dw.action(...)` builds a DwUiAction: it runs
          //    the callback, shows a confirmation first if asked, posts the
          //    success notification, and reports any error with context. Bind
          //    it to any tappable widget with `DwActionBuilder`.
          // -------------------------------------------------------------------
          _Section('Guarded action (confirm → run → notify)', [
            DwActionBuilder(
              action: dw.action<void>(
                (context) async =>
                    await Future<void>.delayed(const Duration(seconds: 1)),
                confirmation: const DwUiConfirmation(
                  'This cannot be undone.',
                  title: 'Delete the thing?',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                ),
                onSuccessNotification: 'Deleted',
              ),
              // The builder gets a ready onPressed (null while busy) and a busy
              // flag — a double tap cannot start it twice, for free.
              builder: (context, onPressed, busy) => FilledButton(
                onPressed: onPressed,
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete (guarded)'),
              ),
            ),
          ]),

          // -------------------------------------------------------------------
          // 5. The async-UI contract. `dwBuildAsync` renders loading / error /
          //    data uniformly. `dwBuildListAsync` does the same for a list, with
          //    skeleton items derived from your real widget.
          // -------------------------------------------------------------------
          _Section('Async rendering', [
            ref
                .watch(_greetingProvider)
                .dwBuildAsync(
                  childBuilder: (value) => Text(value),
                  loadingWidget: const Text('Loading…'),
                ),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(_greetingProvider),
              child: const Text('Reload'),
            ),
          ]),

          // -------------------------------------------------------------------
          //    A list variant: `dwBuildListAsync` renders skeleton rows while
          //    loading. Standalone we pass an explicit `loadingItem`; with the
          //    data layer, `DwConfig.defaultModelGetter` supplies it and the
          //    skeleton is built from your real row widget.
          // -------------------------------------------------------------------
          _Section('Async list', [
            SizedBox(
              width: double.infinity,
              child: ref
                  .watch(_itemsProvider)
                  .dwBuildListAsync(
                    loadingItem: 'Loading…',
                    childBuilder: (items) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final item in items) Text('• $item')],
                    ),
                  ),
            ),
          ]),

          // -------------------------------------------------------------------
          //    Plugins. Declared at startup, resolved by type. A plugin package
          //    (Telegram, prefs) adds a named accessor so you write
          //    `dw.plugins.telegram`; here we resolve the toy plugin directly.
          // -------------------------------------------------------------------
          _Section('Plugins', [
            Text(
              'Clock plugin started at '
              '${dw.plugins.of<_ClockPlugin>().startedAt.toIso8601String()}',
            ),
          ]),

          // -------------------------------------------------------------------
          // 6. Error reporting. Any throw inside a dw.action is reported; you
          //    can also report by hand. Watch the debug console for the snapshot
          //    printed by onErrorReport above.
          // -------------------------------------------------------------------
          _Section('Error reporting', [
            FilledButton.tonal(
              onPressed: () => dw.handleError(
                StateError('a hand-reported error'),
                StackTrace.current,
              ),
              child: const Text('Report an error'),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Feature declarations. Wrap a widget in a DwFeature so the mounted features
//    can be discovered at runtime (feature catalogs, error context, Studio
//    passports). Each section here is one declared feature.
// ---------------------------------------------------------------------------
class _Section extends StatelessWidget implements DwFeature {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  DwFeatureSpec get dwFeature =>
      DwFeatureSpec(id: title, title: title, description: '');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: children),
          ],
        ),
      ),
    );
  }
}
