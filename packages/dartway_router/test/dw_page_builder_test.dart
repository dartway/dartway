import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwPageBuilder', () {
    late BuildContext context;
    late LocalKey key;
    late Widget child;

    setUp(() {
      key = const ValueKey('test');
      child = const Text('Test');
    });

    testWidgets('material should create MaterialPage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.material(context, key, child);
              expect(page, isA<MaterialPage>());
              expect(page.key, key);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('fade should create Page with fade transition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.fade(context, key, child);
              expect(page, isA<Page>());
              expect(page.key, key);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('fade should use default duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.fade(context, key, child);
              expect(page, isA<Page>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('fade should accept custom duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.fade(
                context,
                key,
                child,
                duration: const Duration(milliseconds: 500),
              );
              expect(page, isA<Page>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('slide should create Page with slide transition',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.slide(context, key, child);
              expect(page, isA<Page>());
              expect(page.key, key);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('slide should accept direction parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.slide(
                context,
                key,
                child,
                from: AxisDirection.left,
              );
              expect(page, isA<Page>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('scale should create Page with scale transition',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              final page = DwPageBuilder.scale(context, key, child);
              expect(page, isA<Page>());
              expect(page.key, key);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('defaultTransitionDuration should be 300ms', () {
      expect(
        DwPageBuilder.defaultTransitionDuration,
        const Duration(milliseconds: 300),
      );
    });
  });
}
