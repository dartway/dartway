import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/dartway_starter_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_app.dart';

void main() {
  test('calendar dates are strict canonical civil values', () {
    final leapDay = DwCalendarDay.parse('2024-02-29');
    expect(DwJsonCodec.encodeCalendarDay(leapDay), '2024-02-29');
    expect(leapDay.addDays(1), DwCalendarDay(2024, 3, 1));
    expect(() => DwCalendarDay.parse('2023-02-29'), throwsFormatException);
  });

  testWidgets('signing out through the core ends the session', (tester) async {
    final app = await TestApp.start(tester, FakeApp());
    expect(app.core.client.accountId, testSession.id);
    await app.run(tester, app.core.signOut());
    expect(app.core.client.accountId, isNull);
    await app.stop(tester);
  });
  testWidgets('an action-intercepted disposal error fails harness teardown', (
    tester,
  ) async {
    final app = await TestApp.start(tester, FakeApp());
    final notifier = ValueNotifier<int>(0)..dispose();
    await _runActionFailure(
      app,
      tester,
      () => notifier.addListener(() {}),
      label: 'disposed notifier regression',
    );
    expect(app.server.errors, isEmpty);
    await _expectStopToReportFailure(app, tester);
  });

  testWidgets('consuming one report leaves unrelated reports fatal', (
    tester,
  ) async {
    final app = await TestApp.start(tester, FakeApp());
    await _runActionFailure(
      app,
      tester,
      () => throw StateError('expected incident'),
      label: 'expected incident',
    );

    final expected = app.unexpectedErrorReports.single;
    expect(expected.error, isA<StateError>());
    expect(expected.source, DwErrorSource.uiAction);
    expect(expected.label, 'expected incident');
    app.consumeErrorReport(expected);

    await _runActionFailure(
      app,
      tester,
      () => throw ArgumentError('unrelated incident'),
      label: 'unrelated incident',
    );
    expect(app.server.errors, isEmpty);
    expect(app.unexpectedErrorReports, hasLength(1));
    await _expectStopToReportFailure(app, tester);
  });

  testWidgets('business refusals do not count as unexpected reports', (
    tester,
  ) async {
    final app = await TestApp.start(tester, FakeApp());
    await _runActionFailure(
      app,
      tester,
      () => throw DwRefusalException(DwCallRefusal(DwCoreRefusal.notFound)),
      label: 'normal not-found refusal',
    );
    expect(app.unexpectedErrorReports, isEmpty);
    await app.stop(tester);
  });

  testWidgets('teardown reports errors, restores hooks and releases the core', (
    tester,
  ) async {
    final oldFlutterError = FlutterError.onError;
    final oldPlatformError = tester.binding.platformDispatcher.onError;
    final app = await TestApp.start(tester, FakeApp());
    await tester.pumpWidget(const MaterialApp(home: _ReportErrorOnDispose()));

    await _expectStopToReportFailure(app, tester);
    expect(FlutterError.onError, same(oldFlutterError));
    expect(tester.binding.platformDispatcher.onError, same(oldPlatformError));

    final next = await TestApp.start(tester, FakeApp());
    expect(next.unexpectedErrorReports, isEmpty);
    await next.stop(tester);
  });

  testWidgets('the harness can use production release timing when needed', (
    tester,
  ) async {
    final fast = await TestApp.start(tester, FakeApp());
    expect(fast.core.client.options.releaseDelay, Duration.zero);
    await fast.stop(tester);

    final production = await TestApp.start(
      tester,
      FakeApp(),
      clientOptions: const DwClientOptions(),
    );
    expect(
      production.core.client.options.releaseDelay,
      const Duration(seconds: 1),
    );
    await production.stop(tester);
  });
}

Future<void> _runActionFailure(
  TestApp app,
  WidgetTester tester,
  void Function() action, {
  required String label,
}) async {
  final context = tester.element(find.byType(AppRoot));
  await app.run(
    tester,
    dw.action<void>((_) => action(), label: label)(context),
  );
}

Future<void> _expectStopToReportFailure(
  TestApp app,
  WidgetTester tester,
) async {
  Object? stopError;
  try {
    await app.stop(tester);
  } catch (error) {
    stopError = error;
  }
  expect(stopError, isNotNull, reason: 'an unexpected report must fail stop');
  expect('$stopError', contains('unexpected DartWay error reports'));
}

final class _ReportErrorOnDispose extends StatefulWidget {
  const _ReportErrorOnDispose();

  @override
  State<_ReportErrorOnDispose> createState() => _ReportErrorOnDisposeState();
}

final class _ReportErrorOnDisposeState extends State<_ReportErrorOnDispose> {
  @override
  void dispose() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('error during widget teardown'),
        stack: StackTrace.current,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
