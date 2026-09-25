import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A model with no placeholder configured — the shape of every model a
/// widget test does not pass a `loadingItem`/`loadingValue` for.
class _Unknown {
  const _Unknown(this.title);
  final String title;
}

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  // One DwFlutterToolbox per test process — the singleton forbids re-creation.
  final errorReports = <DwErrorReport>[];
  DwFlutterToolbox(config: DwFlutterConfig(onErrorReport: errorReports.add));

  group('dwBuildListAsync builds its placeholder lazily', () {
    testWidgets('data renders without building a placeholder', (
      tester,
    ) async {
      const data = AsyncValue<List<_Unknown>>.data([_Unknown('real')]);

      await tester.pumpWidget(
        _host(
          data.dwBuildListAsync(
            childBuilder: (items) =>
                Column(children: [for (final i in items) Text(i.title)]),
          ),
        ),
      );

      expect(find.text('real'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty list is still just an empty list', (tester) async {
      const data = AsyncValue<List<_Unknown>>.data([]);

      await tester.pumpWidget(
        _host(
          data.dwBuildListAsync(
            childBuilder: (items) => Text('${items.length} items'),
          ),
        ),
      );

      expect(find.text('0 items'), findsOneWidget);
    });

    testWidgets('error renders the error widget', (tester) async {
      final failed = AsyncValue<List<_Unknown>>.error(
        StateError('boom'),
        StackTrace.empty,
      );

      await tester.pumpWidget(
        _host(
          failed.dwBuildListAsync(
            childBuilder: (items) => const Text('unreachable'),
            errorWidget: const Text('failed'),
          ),
        ),
      );

      expect(find.text('failed'), findsOneWidget);
      expect(find.text('unreachable'), findsNothing);
    });

    testWidgets('loadingItem builds and skeletonizes the placeholder', (
      tester,
    ) async {
      const loading = AsyncValue<List<_Unknown>>.loading();

      await tester.pumpWidget(
        _host(
          loading.dwBuildListAsync(
            loadingItem: const _Unknown('placeholder'),
            loadingItemsCount: 2,
            childBuilder: (items) =>
                Column(children: [for (final i in items) Text(i.title)]),
          ),
        ),
      );

      expect(find.text('placeholder'), findsNWidgets(2));
      expect(find.byType(SkeletonizerScope), findsOneWidget);
    });

    testWidgets('with no loadingItem, loading renders nothing, as a single '
        'value does — never an error block', (tester) async {
      errorReports.clear();
      const loading = AsyncValue<List<_Unknown>>.loading();

      await tester.pumpWidget(
        _host(
          loading.dwBuildListAsync(
            childBuilder: (items) => const Text('unreachable'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('unreachable'), findsNothing);
      expect(find.byType(SkeletonizerScope), findsNothing);
      expect(errorReports, isEmpty);
    });
  });

  group('dwBuildAsync', () {
    testWidgets('data renders without building a placeholder', (
      tester,
    ) async {
      const data = AsyncValue<_Unknown>.data(_Unknown('real'));

      await tester.pumpWidget(
        _host(data.dwBuildAsync(childBuilder: (value) => Text(value.title))),
      );

      expect(find.text('real'), findsOneWidget);
    });

    testWidgets('with no loadingValue, loading renders nothing', (
      tester,
    ) async {
      const loading = AsyncValue<_Unknown>.loading();

      await tester.pumpWidget(
        _host(loading.dwBuildAsync(childBuilder: (value) => Text(value.title))),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonizerScope), findsNothing);
    });

    testWidgets('loadingWidget wins over the placeholder', (tester) async {
      const loading = AsyncValue<_Unknown>.loading();

      await tester.pumpWidget(
        _host(
          loading.dwBuildAsync(
            childBuilder: (value) => Text(value.title),
            loadingWidget: const Text('spinner'),
          ),
        ),
      );

      expect(find.text('spinner'), findsOneWidget);
    });

    testWidgets('error builder receives the original async failure', (
      tester,
    ) async {
      errorReports.clear();
      final failure = StateError('offline snapshot unavailable');
      final asyncValue = AsyncValue<int>.error(failure, StackTrace.current);

      await tester.pumpWidget(
        _host(
          asyncValue.dwBuildAsync(
            childBuilder: (value) => Text('$value'),
            errorBuilder: (error, _) => Text('handled: $error'),
          ),
        ),
      );

      expect(
        find.text('handled: Bad state: offline snapshot unavailable'),
        findsOneWidget,
      );
      expect(errorReports.single.error, same(failure));
    });
  });
}
