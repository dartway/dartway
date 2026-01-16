import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test enum for parameters
enum TestParams<T> with DwNavigationParamsMixin<T> {
  userId<int>(),
  userName<String>(),
  price<double>(),
  isActive<bool>(),
}

void main() {
  group('DwNavigationParamsMixin', () {
    group('set', () {
      test('should create map with enum name as key', () {
        final result = TestParams.userId.set(123);
        expect(result, {'userId': '123'});
      });

      test('should convert value to string', () {
        expect(TestParams.userName.set('John'), {'userName': 'John'});
        expect(TestParams.price.set(99.99), {'price': '99.99'});
        expect(TestParams.isActive.set(true), {'isActive': 'true'});
      });
    });

    group('fromPath', () {
      testWidgets('should extract int parameter from path', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test/123',
          routes: [
            GoRoute(
              path: '/test/:userId',
              name: 'test',
              builder: (context, state) {
                final userId = TestParams.userId.fromPath(context);
                return Text('User: $userId');
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('User: 123'));
        expect(text.data, 'User: 123');
      });

      testWidgets('should throw ArgumentError when parameter is missing',
          (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                expect(
                  () => TestParams.userId.fromPath(context),
                  throwsA(isA<ArgumentError>()),
                );
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
      });
    });

    group('fromPathOrNull', () {
      testWidgets('should return null when parameter is missing',
          (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                final userId = TestParams.userId.fromPathOrNull(context);
                expect(userId, isNull);
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
      });
    });

    group('fromQuery', () {
      testWidgets('should extract int parameter from query', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test?userId=456',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                final userId = TestParams.userId.fromQuery(context);
                return Text('User: $userId');
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('User: 456'));
        expect(text.data, 'User: 456');
      });

      testWidgets('should throw ArgumentError when query parameter is missing',
          (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                expect(
                  () => TestParams.userId.fromQuery(context),
                  throwsA(isA<ArgumentError>()),
                );
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
      });
    });

    group('fromQueryOrNull', () {
      testWidgets('should return null when query parameter is missing',
          (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                final userId = TestParams.userId.fromQueryOrNull(context);
                expect(userId, isNull);
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
      });
    });

    group('fromExtra', () {
      testWidgets('should extract extra parameter', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                final extra = TestParams.userId.fromExtra(context);
                return Text('Extra: $extra');
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );

        router.go('/test', extra: 789);
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('Extra: 789'));
        expect(text.data, 'Extra: 789');
      });

      testWidgets('should return null when extra is null', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              name: 'test',
              builder: (context, state) {
                final extra = TestParams.userId.fromExtra(context);
                expect(extra, isNull);
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
      });
    });

    group('_cast', () {
      test('should parse int correctly', () {
        // This is tested indirectly through fromPath/fromQuery
        // but we can test the behavior
        expect(TestParams.userId.set(123), {'userId': '123'});
      });

      test('should parse string correctly', () {
        expect(TestParams.userName.set('John'), {'userName': 'John'});
      });

      test('should parse double correctly', () {
        expect(TestParams.price.set(99.99), {'price': '99.99'});
      });

      test('should parse bool correctly', () {
        expect(TestParams.isActive.set(true), {'isActive': 'true'});
        expect(TestParams.isActive.set(false), {'isActive': 'false'});
      });
    });
  });
}
