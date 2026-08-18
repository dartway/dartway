import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A model the app's placeholder registry knows about.
class _Known {
  const _Known(this.title);
  final String title;
}

/// A model it does not — the shape of every model a widget test never
/// registered, which is all of them until the test says otherwise.
class _Unknown {
  const _Unknown(this.title);
  final String title;
}

/// Stands in for an app's `DefaultModels` repository: it answers for the models
/// it was told about and throws for the rest, message and all.
T _defaultModelGetter<T>() {
  if (T == _Known) return const _Known('placeholder') as T;

  throw UnimplementedError(
    "Default Objects Repository doesn't contain a model of type $T",
  );
}

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  // One DwFlutter per test process — the singleton forbids re-creation.
  final errorReports = <DwErrorReport>[];
  DwFlutter(
    config: DwConfig(
      defaultModelGetter: _defaultModelGetter,
      onErrorReport: errorReports.add,
    ),
  );

  group('dwBuildListAsync builds its placeholder lazily', () {
    testWidgets('data renders without reaching the placeholder registry', (
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

    testWidgets('error renders the error widget, registry untouched', (
      tester,
    ) async {
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

    testWidgets('loading does reach the registry, and skeletonizes', (
      tester,
    ) async {
      const loading = AsyncValue<List<_Known>>.loading();

      await tester.pumpWidget(
        _host(
          loading.dwBuildListAsync(
            loadingItemsCount: 2,
            childBuilder: (items) =>
                Column(children: [for (final i in items) Text(i.title)]),
          ),
        ),
      );

      expect(find.text('placeholder'), findsNWidgets(2));
      expect(find.byType(SkeletonizerScope), findsOneWidget);
    });

    testWidgets('loadingItem keeps the registry out of it entirely', (
      tester,
    ) async {
      const loading = AsyncValue<List<_Unknown>>.loading();

      await tester.pumpWidget(
        _host(
          loading.dwBuildListAsync(
            loadingItem: const _Unknown('mine'),
            loadingItemsCount: 1,
            childBuilder: (items) =>
                Column(children: [for (final i in items) Text(i.title)]),
          ),
        ),
      );

      expect(find.text('mine'), findsOneWidget);
    });
  });

  group('dwBuildAsync', () {
    testWidgets('data renders without reaching the placeholder registry', (
      tester,
    ) async {
      const data = AsyncValue<_Unknown>.data(_Unknown('real'));

      await tester.pumpWidget(
        _host(data.dwBuildAsync(childBuilder: (value) => Text(value.title))),
      );

      expect(find.text('real'), findsOneWidget);
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
