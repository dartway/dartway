import 'dart:async';

import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// --- a log of lines, windowed ------------------------------------------------

enum LogChannel with DwChannelKind { log }

const logChannel = DwLiveChannel(LogChannel.log);

final class LogLine extends DwDataObject {
  const LogLine(this.id);

  @override
  final int id;

  /// Rows of different heights, as messages are.
  double get height => 40.0 + (id % 4) * 15;

  @override
  String get dwTypeName => 'LogLine';

  @override
  Map<String, Object?> toJson() => {'id': id};

  @override
  bool operator ==(Object other) => other is LogLine && other.id == id;

  @override
  int get hashCode => id;
}

final class ReadLog extends DwWindowRequest<LogLine, int, int> {
  const ReadLog() : super(pageSize: 20, maxPageSize: 100);

  @override
  DwWindowPosition<int, int> positionOf(LogLine item) =>
      (sortValue: item.id, id: item.id);

  @override
  List<DwLiveChannel> get channels => const [logChannel];

  @override
  String get dwTypeName => 'ReadLog';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is ReadLog;

  @override
  int get hashCode => (ReadLog).hashCode;
}

final logProtocol = DwWireProtocol([
  DwProtocolEntry<LogLine>('LogLine', (json) => LogLine(json['id']! as int)),
  DwProtocolEntry<ReadLog>('ReadLog', (json) => const ReadLog()),
], include: DwWireProtocol.core);

const session = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);

final class LogWorld {
  LogWorld(int count)
    : lines = [for (var id = count; id >= 1; id--) LogLine(id)] {
    server
      ..registerToken(session.token, session.id)
      ..onRequest<ReadLog>((request, call) async {
        final query = call.page;
        if (query is DwWindowQuery &&
            query.direction == DwWindowDirection.older) {
          await olderGate?.future;
        }
        return DwCallOk(dwFakeWindow(lines, request, call.page));
      });
  }

  final server = DwFakeServer(protocol: logProtocol);

  /// Newest first.
  List<LogLine> lines;

  /// While set, reads of older lines wait for it.
  Completer<void>? olderGate;

  void add(int id) {
    final line = LogLine(id);
    lines = [line, ...lines];
    server.publish(logChannel, [line]);
  }

  List<Map<String, String>> get queries => [
    for (final call in server.callsOf<ReadLog>()) call.query,
  ];

  DwFlutterCore core() => DwFlutterCore(
    config: DwFlutterConfig(
      appVersion: '1.0.0+1',
      refusalText: (refusal) => refusal.code,
    ),
    protocol: logProtocol,
    baseUrl: server.baseUrl,
    httpTransport: server.httpTransport,
    liveConnector: server.liveConnector,
    tokenStore: DwMemoryTokenStore(session),
    clientOptions: dwFakeClientOptions,
  );
}

const listHeight = 600.0;

/// The oldest line any row was built for.
int oldestBuilt = 1 << 30;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Widget logList({
  required DwWindowListController<LogLine> controller,
  String? anchor,
  double anchorAlignment = 0.35,
  void Function(List<LogLine>)? onVisible,
}) => ProviderScope(
  child: MaterialApp(
    home: Material(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: listHeight,
          child: DwWindowListView<LogLine>(
            request: const ReadLog(),
            controller: controller,
            initialAnchor: anchor,
            anchorAlignment: anchorAlignment,
            onVisibleItemsChanged: onVisible,
            itemBuilder: (context, row) {
              if (row.item.id < oldestBuilt) oldestBuilt = row.item.id;
              return SizedBox(
                key: ValueKey('line-${row.item.id}'),
                height: row.item.height,
                child: Text(
                  row.isHighlighted
                      ? 'line ${row.item.id} (here)'
                      : 'line ${row.item.id}',
                ),
              );
            },
          ),
        ),
      ),
    ),
  ),
);

Finder line(int id) => find.byKey(ValueKey('line-$id'));

double topOf(WidgetTester tester, int id) => tester.getTopLeft(line(id)).dy;

double bottomOf(WidgetTester tester, int id) =>
    tester.getBottomLeft(line(id)).dy;

String cursor(int id) => DwWindowCursor.encode(id, id);

void main() {
  late LogWorld world;
  late DwFlutterCore dw;
  late DwWindowListController<LogLine> controller;

  Future<void> open(
    WidgetTester tester,
    int count, {
    String? anchor,
    double anchorAlignment = 0.35,
    void Function(List<LogLine>)? onVisible,
  }) async {
    oldestBuilt = 1 << 30;
    world = LogWorld(count);
    dw = world.core();
    await dw.init();
    controller = DwWindowListController<LogLine>();
    await tester.pumpWidget(
      logList(
        controller: controller,
        anchor: anchor,
        anchorAlignment: anchorAlignment,
        onVisible: onVisible,
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    controller.dispose();
    await dw.dispose();
    expect(world.server.errors, isEmpty);
  }

  testWidgets('opens at the newest line, at the bottom, without reversing', (
    tester,
  ) async {
    await open(tester, 200);
    expect(bottomOf(tester, 200), moreOrLessEquals(listHeight, epsilon: 1));
    expect(topOf(tester, 199), lessThan(topOf(tester, 200)));
    expect(find.byType(CustomScrollView), findsOneWidget);
    final view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.reverse, isFalse);
    expect(controller.isAtNewest.value, isTrue);
    expect(controller.newerCount.value, 0);
    await close(tester);
  });

  testWidgets('older lines loaded above keep the first visible line within a '
      'pixel of where it was', (tester) async {
    await open(tester, 400);
    world.olderGate = Completer<void>();
    final calls = world.queries.length;

    // Up until the list asks for older lines; the read waits at the gate.
    for (var i = 0; i < 30 && world.queries.length == calls; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 150));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(world.queries.last, contains('before'));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    final first = controller.topVisibleItem.value!;
    final y = topOf(tester, first.id);
    final oldestBefore = oldestBuilt;

    world.olderGate!.complete();
    world.olderGate = null;
    await settle(tester);

    expect(topOf(tester, first.id), moreOrLessEquals(y, epsilon: 1));
    expect(controller.topVisibleItem.value, first);
    // The rows it brought are there, above.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await settle(tester);
    expect(oldestBuilt, lessThan(oldestBefore - 5));
    await close(tester);
  });

  testWidgets('at the newest line, a new line arrives in view at the bottom', (
    tester,
  ) async {
    await open(tester, 30);
    world.add(31);
    await settle(tester);
    expect(bottomOf(tester, 31), moreOrLessEquals(listHeight, epsilon: 1));
    expect(controller.isAtNewest.value, isTrue);
    expect(controller.newerCount.value, 0);

    world.add(32);
    world.add(33);
    await settle(tester);
    expect(bottomOf(tester, 33), moreOrLessEquals(listHeight, epsilon: 1));
    await close(tester);
  });

  testWidgets('scrolled up, new lines move nothing and are counted; the jump '
      'goes to them', (tester) async {
    await open(tester, 80);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await settle(tester);
    final first = controller.topVisibleItem.value!;
    final y = topOf(tester, first.id);
    expect(controller.isAtNewest.value, isFalse);
    expect(controller.newerCount.value, 0);

    world.add(81);
    await settle(tester);
    expect(topOf(tester, first.id), moreOrLessEquals(y, epsilon: 1));
    expect(controller.newerCount.value, 1);
    world.add(82);
    await settle(tester);
    expect(topOf(tester, first.id), moreOrLessEquals(y, epsilon: 1));
    expect(controller.newerCount.value, 2);
    expect(line(82), findsNothing);

    unawaited(controller.jumpToNewest());
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(bottomOf(tester, 82), moreOrLessEquals(listHeight, epsilon: 1));
    expect(controller.isAtNewest.value, isTrue);
    expect(controller.newerCount.value, 0);
    await close(tester);
  });

  testWidgets('opens at the anchor: its bottom at the alignment, what follows '
      'right below; with little to follow, at the end', (tester) async {
    await open(tester, 300, anchor: cursor(120), anchorAlignment: 0.5);
    expect(world.queries.first, containsPair('anchor', cursor(120)));
    expect(bottomOf(tester, 120), moreOrLessEquals(300, epsilon: 1));
    expect(topOf(tester, 121), moreOrLessEquals(300, epsilon: 1));
    expect(controller.isAtNewest.value, isFalse);
    expect(controller.newerCount.value, greaterThan(0));
    await close(tester);

    await open(tester, 80, anchor: cursor(78), anchorAlignment: 0.3);
    expect(bottomOf(tester, 80), moreOrLessEquals(listHeight, epsilon: 1));
    expect(controller.isAtNewest.value, isTrue);
    await close(tester);
  });

  testWidgets('scrolling to a line that is not loaded reopens the window '
      'around it, and highlights it', (tester) async {
    await open(tester, 400);
    expect(line(50), findsNothing);

    final done = controller.scrollToCursor(cursor(50), alignment: 0.3);
    await settle(tester);
    expect(await done, isTrue);
    expect(world.queries, contains(containsPair('anchor', cursor(50))));
    expect(topOf(tester, 50), moreOrLessEquals(0.3 * listHeight, epsilon: 1));
    expect(find.text('line 50 (here)'), findsOneWidget);
    expect(controller.isAtNewest.value, isFalse);

    // A loaded line near by is scrolled to without a read.
    final reads = world.queries.length;
    final near = controller.scrollToCursor(cursor(47), alignment: 0.3);
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(await near, isTrue);
    expect(world.queries.length, reads);
    expect(topOf(tester, 47), moreOrLessEquals(0.3 * listHeight, epsilon: 1));

    // Back to the newest, which is not loaded: the window reopens there.
    unawaited(controller.jumpToNewest());
    await settle(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(world.queries, contains(isEmpty), reason: 'the newest lines');
    expect(bottomOf(tester, 400), moreOrLessEquals(listHeight, epsilon: 1));
    await close(tester);
  });

  testWidgets('reports the lines on screen, newest first, once the list '
      'rests', (tester) async {
    final reports = <List<int>>[];
    await open(
      tester,
      300,
      anchor: cursor(100),
      anchorAlignment: 0.5,
      onVisible: (visible) => reports.add([for (final l in visible) l.id]),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(reports, isNotEmpty);
    final last = reports.last;
    expect(last, contains(100));
    expect(last, contains(101));
    expect(last.first, greaterThan(last.last));
    expect(
      last,
      everyElement(
        isA<int>().having((id) => id, 'id', inInclusiveRange(80, 120)),
      ),
    );

    final count = reports.length;
    // A fling of small drags reports once, after it stops.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(reports.length, count);
    await tester.pump(const Duration(milliseconds: 400));
    expect(reports.length, count + 1);
    expect(reports.last.first, greaterThan(last.first));
    await close(tester);
  });
}
