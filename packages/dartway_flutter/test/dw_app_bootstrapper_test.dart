import 'package:dartway_flutter/src/bootstrap/logic/dw_app_loading_options.dart';
import 'package:dartway_flutter/src/bootstrap/widgets/dw_app_bootstrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bootstrapper({
  required List<Future<void> Function()> initializers,
  void Function(Object, StackTrace)? onError,
  Widget Function(Object, StackTrace)? errorScreenBuilder,
}) => MediaQuery(
  data: const MediaQueryData(),
  child: DwAppBootstrapper(
    appInitializers: initializers,
    useNativeSplash: false,
    onError: onError ?? (_, _) {},
    errorScreenBuilder:
        errorScreenBuilder ?? DwAppLoadingOptions.defaultErrorScreen,
    loadingScreen: const SizedBox.shrink(),
    child: const Text('the app', textDirection: TextDirection.ltr),
  ),
);

void main() {
  testWidgets('a start that succeeds renders the app', (tester) async {
    await tester.pumpWidget(_bootstrapper(initializers: [() async {}]));
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a failed start says so, and says what failed', (tester) async {
    await tester.pumpWidget(
      _bootstrapper(
        initializers: [() async => throw Exception('no database')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsNothing);
    expect(find.text('The app could not start'), findsOneWidget);
    // The failure itself is on the screen: without it the person looking at it
    // has nothing to report but "the app is broken".
    expect(find.textContaining('no database'), findsOneWidget);
  });

  testWidgets('a reporter that throws does not eat the screen', (
    tester,
  ) async {
    // The handler runs against a core that has just failed to start, and its
    // out-of-the-box alerting talks to the server the start could not reach.
    // A throw in there used to leave the app on the loading screen — under a
    // native splash a `SizedBox.shrink()`, which is nothing at all, for good.
    await tester.pumpWidget(
      _bootstrapper(
        initializers: [() async => throw Exception('no database')],
        onError: (_, _) => throw StateError('the reporter is broken too'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The app could not start'), findsOneWidget);
  });

  testWidgets('the error screen is built from the error', (tester) async {
    Object? seen;
    await tester.pumpWidget(
      _bootstrapper(
        initializers: [() async => throw Exception('no database')],
        errorScreenBuilder: (error, _) {
          seen = error;
          return const Text('mine', textDirection: TextDirection.ltr);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mine'), findsOneWidget);
    expect(seen.toString(), contains('no database'));
  });
}
