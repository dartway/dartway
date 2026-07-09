import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeatureBox extends StatelessWidget implements DwFeature {
  const _FeatureBox(this.id);

  final String id;

  @override
  DwFeatureSpec get dwFeature =>
      DwFeatureSpec(id: id, title: id, description: '');

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  final reports = <DwErrorReport>[];

  // One DwFlutter per test process — the singleton forbids re-creation.
  final dwInstance = DwFlutter(
    config: DwConfig(
      appVersion: '1.2.3',
      onErrorReport: reports.add,
    ),
  );

  setUp(() {
    reports.clear();
    dwInstance.errorContext.registerRouteSource(() => '/test-route');
  });

  group('error pipeline', () {
    testWidgets('DwUiAction failure produces a full DwErrorReport',
        (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              const _FeatureBox('feature-a'),
              Builder(builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      );

      final action = DwUiAction<void>.create(
        (_) => throw StateError('boom'),
        label: 'testAction',
      );
      await action(capturedContext);
      await tester.pump();

      expect(reports, hasLength(1));
      final report = reports.single;
      expect(report.source, DwErrorSource.uiAction);
      expect(report.actionLabel, 'testAction');
      expect(report.error, isA<StateError>());
      expect(report.context.route, '/test-route');
      expect(report.context.featureIds, contains('feature-a'));
      expect(report.context.appVersion, '1.2.3');
    });

    testWidgets('action label falls back to the notification text',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final action = DwUiAction<void>.create(
        (_) => throw StateError('boom'),
        onErrorNotification: 'Could not save',
      );
      await action(context);

      expect(reports.single.actionLabel, 'Could not save');
    });

    test('manual handleError captures context too', () {
      dwInstance.handleError(StateError('manual'), StackTrace.current);

      final report = reports.single;
      expect(report.source, DwErrorSource.manual);
      expect(report.context.route, '/test-route');
    });

    test('a broken context provider never breaks reporting', () {
      dwInstance.errorContext.register('bad', () => throw StateError('nope'));
      dwInstance.errorContext.set('good', 'value');

      dwInstance.handleError(StateError('x'), StackTrace.current);

      final report = reports.single;
      expect(report.context.entries, {'good': 'value'});
    });
  });

  group('DwUiAction confirmation', () {
    testWidgets('declined confirmation skips the action', (tester) async {
      var executed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => DwUiAction<void>.create(
                (_) async => executed = true,
                confirmation: const DwUiConfirmation('Sure?'),
              )(context),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(executed, isFalse);
      expect(reports, isEmpty);
    });

    testWidgets('accepted confirmation runs the action', (tester) async {
      var executed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => DwUiAction<void>.create(
                (_) async => executed = true,
                confirmation: const DwUiConfirmation(
                  'Sure?',
                  confirmLabel: 'Yes, delete',
                  isDestructive: true,
                ),
              )(context),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, delete'));
      await tester.pumpAndSettle();

      expect(executed, isTrue);
    });
  });
}
