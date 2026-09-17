import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects what `dw.notify.*` delivered, in place of showing it.
class _CapturingHandler implements DwNotificationHandler<DwUiNotification> {
  final shown = <DwUiNotification>[];

  @override
  void show(BuildContext context, DwUiNotification event) => shown.add(event);
}

class _FeatureBox extends StatelessWidget implements DwFeatureWidget {
  const _FeatureBox(this.id);

  final String id;

  @override
  DwFeatureSpec get dwFeature => DwFeatureSpec(id: id, title: id);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  final reports = <DwErrorReport>[];

  // One core for the whole file: nothing here disposes it.
  final dwInstance = DwFlutterToolbox(
    config: DwFlutterConfig(
      appVersion: '1.2.3',
      onErrorReport: reports.add,
      refusalText: (refusal) => switch (refusal.code) {
        'messageDeleted' => 'This message was already deleted',
        _ => 'Refused: ${refusal.code}',
      },
    ),
  );

  setUp(() {
    reports.clear();
    dwInstance.errorContext.registerRouteSource(() => '/test-route');
  });

  group('error pipeline', () {
    testWidgets('DwUiAction failure produces a full DwErrorReport', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              const _FeatureBox('feature-a'),
              Builder(
                builder: (context) {
                  capturedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );

      final action = dwInstance.action<void>(
        (_) => throw StateError('boom'),
        label: 'testAction',
      );
      await action(capturedContext);
      await tester.pump();

      expect(reports, hasLength(1));
      final report = reports.single;
      expect(report.source, DwErrorSource.uiAction);
      expect(report.label, 'testAction');
      expect(report.error, isA<StateError>());
      expect(report.context.route, '/test-route');
      expect(report.context.featureIds, contains('feature-a'));
      expect(report.context.appVersion, '1.2.3');
    });

    testWidgets('action label falls back to the notification text', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final action = dwInstance.action<void>(
        (_) => throw StateError('boom'),
        onErrorNotification: 'Could not save',
      );
      await action(context);

      expect(reports.single.label, 'Could not save');
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

  group('a refusal is an answer, not an incident', () {
    final notifications = _CapturingHandler();

    /// The app as a refusal meets it: a notification listener mounted, so what
    /// `dw.action` decides to show is observable.
    Future<BuildContext> pumpApp(WidgetTester tester) async {
      notifications.shown.clear();
      await tester.pumpWidget(
        ProviderScope(
          child: DwNotificationsListener(
            handlers: {DwUiNotification: notifications},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      return tester.element(find.byType(SizedBox));
    }

    testWidgets('is shown to the user in its own words', (tester) async {
      final context = await pumpApp(tester);

      final action = dwInstance.action<void>(
        (_) => throw DwRefusalException(DwCallRefusal(_Refusal.messageDeleted)),
        onErrorNotification: 'Could not delete',
      );
      await action(context);
      await tester.pump();

      // The catalogue's text for the refusal wins over the action's generic
      // one: it was written for this case, and the generic one for every case.
      expect(
        notifications.shown.single.message,
        'This message was already deleted',
      );
      expect(notifications.shown.single.type, DwUiNotificationType.error);
    });

    testWidgets('an ordinary failure still shows the action text', (
      tester,
    ) async {
      final context = await pumpApp(tester);

      final action = dwInstance.action<void>(
        (_) => throw StateError('boom'),
        onErrorNotification: 'Could not delete',
      );
      await action(context);
      await tester.pump();

      expect(notifications.shown.single.message, 'Could not delete');
    });

    testWidgets('a refused result is shown the same way, without unwrapping', (
      tester,
    ) async {
      final context = await pumpApp(tester);

      final value = await dwInstance.action<DwCallResult<int>>(
        (_) async => DwCallRefused<int>(DwCallRefusal(_Refusal.messageDeleted)),
        onSuccessNotification: 'Deleted',
      )(context);
      await tester.pump();

      expect(value, isNull);
      expect(
        notifications.shown.single.message,
        'This message was already deleted',
      );
    });

    testWidgets('a failed result shows the action text and names the call', (
      tester,
    ) async {
      final context = await pumpApp(tester);

      await dwInstance.action<DwCallResult<int>>(
        (_) async => const DwCallFailed<int>('incident-9'),
        onErrorNotification: 'Could not delete',
      )(context);
      await tester.pump();

      expect(notifications.shown.single.message, 'Could not delete');
      expect(reports.single.error, const DwFailedException('incident-9'));
    });

    testWidgets('still reaches the error policy, as a DwRefusalException', (
      tester,
    ) async {
      final context = await pumpApp(tester);

      await dwInstance.action<void>(
        (_) => throw DwRefusalException(DwCallRefusal(_Refusal.noAccess)),
      )(context);

      // The app decides what to do with it — the point of the type is that
      // one check is enough: `if (report.error is DwRefusalException) return;`
      expect(reports.single.error, isA<DwRefusalException>());
      expect(
        (reports.single.error as DwRefusalException).refusal.code,
        'noAccess',
      );
    });
  });

  group('DwUiAction confirmation', () {
    testWidgets('declined confirmation skips the action', (tester) async {
      var executed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => dwInstance.action<void>(
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
              onPressed: () => dwInstance.action<void>(
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

enum _Refusal with DwRefusalCodes { messageDeleted, noAccess }
