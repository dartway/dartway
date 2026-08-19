import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The path an application actually takes, end to end: a feature that reads
/// and writes for itself, rendered against a core booted the way an app boots
/// one, with the server standing in as a [DwRecordingServerTransport].
///
/// Every other test in this package calls the repository directly or holds the
/// core in a local variable. This one deliberately does neither — the core is a
/// library-level `dw`, exactly as an app declares it, and the widget reaches it
/// ambiently. That is the difference between testing the framework and testing
/// the way the framework is used.
void main() {
  final transport = DwRecordingServerTransport(
    classNames: <Type, String>{_Task: 'Task'},
  );

  setUpAll(() => _bootTestCore(transport));

  setUp(() {
    transport.reset();
    // The feature reads a list on every build, so this is the baseline every
    // test starts from; the tests that care about the read replace it.
    transport.answerGetAll = (_) async => _tasksResponse(const <_Task>[]);
  });

  testWidgets('a feature draws what the transport answered', (tester) async {
    transport.answerGetAll = (_) async => _tasksResponse(const <_Task>[
      _Task(id: 1, title: 'Buy milk'),
      _Task(id: 2, title: 'Call the dentist'),
    ]);

    await tester.pumpWidget(const _App());
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call the dentist'), findsOneWidget);
    expect(transport.reads.single.className, 'Task');
  });

  testWidgets('the tap leaves as a save, carrying what the feature built', (
    tester,
  ) async {
    await tester.pumpWidget(const _App());
    await tester.pumpAndSettle();

    expect(transport.saves, isEmpty, reason: 'nothing saves on render alone');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(transport.saves, hasLength(1));
    final saved = transport.saves.single;
    expect(saved.wrappedModel.className, 'Task');
    expect((saved.model as _Task).title, 'A new task');
    expect(saved.apiGroup, isNull);
  });

  testWidgets('the saved model comes back and the list shows it', (
    tester,
  ) async {
    // The server assigns the id, as a real one does on insert.
    transport.answerSave = (save) async {
      final task = save.model as _Task;
      final stored = _Task(id: 42, title: task.title);
      return DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(model: stored),
        updatedModels: <DwModelWrapper>[DwModelWrapper.wrap(model: stored)],
      );
    };

    await tester.pumpWidget(const _App());
    await tester.pumpAndSettle();
    expect(find.text('A new task'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Not re-fetched: the save's `updatedModels` reached the open list through
    // the repository's own update dispatch.
    expect(transport.reads, hasLength(1));
    expect(find.text('A new task'), findsOneWidget);
  });

  testWidgets(
    'a read nobody prepared names itself and the field that answers',
    (tester) async {
      transport.answerGetAll = null;

      await tester.pumpWidget(const _App());
      await tester.pumpAndSettle();

      expect(find.textContaining('DwUnpreparedServerCall'), findsOneWidget);
      expect(find.textContaining('answerGetAll'), findsOneWidget);
      expect(
        transport.reads.single.operation,
        'getAll',
        reason: 'the attempt is recorded even though it had no answer',
      );
    },
  );

  test('a core with neither a client nor a transport says so', () {
    expect(
      () => DwCore<ServerpodClientShared, _Task>(
        config: const DwConfig(),
        dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
        getUserId: (_) => null,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(contains('client:'), contains('transport:')),
        ),
      ),
    );
  });

  test('dw.client on a transport-only core says how the core was built', () {
    expect(
      () => dw.client,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('without a Serverpod client'),
        ),
      ),
    );
  });
}

// --- The app half ------------------------------------------------------------
//
// Written the way `template/dartway_starter_flutter/lib/core/dw_core.dart` is,
// down to the idempotency guard: a test file must be able to boot the core from
// `setUpAll` without knowing whether another one got there first.

late final DwCore<ServerpodClientShared, _Task> dw;

bool _coreInitialized = false;

void _bootTestCore(DwServerTransport transport) {
  if (_coreInitialized) return;
  _coreInitialized = true;

  dw = DwCore<ServerpodClientShared, _Task>(
    config: const DwConfig(defaultModelGetter: dwGetDefault),
    // Instead of a client, not beside one: nothing here stands up Serverpod.
    transport: transport,
    dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
    getUserId: (task) => task?.id,
  );

  dw.repo.setupRepository(defaultModel: const _Task(id: 0, title: ''));
}

/// A feature that reads and writes for itself — no callbacks handed in, so the
/// only thing a test can observe is what left for the server.
class _TaskFeature extends ConsumerWidget {
  const _TaskFeature();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built here rather than inside the callback, which is what makes a booted
    // core a prerequisite for *rendering* and not only for tapping.
    final addTask = dw.action<_Task>(
      (_) => dw.repo.saveModel(const _Task(title: 'A new task')),
      label: 'addTask',
      onSuccessNotification: 'Task added',
    );

    final tasks = ref.watch(dw.repo.modelList<_Task>());

    return Scaffold(
      body: switch (tasks) {
        AsyncData(:final value) => ListView(
          children: <Widget>[for (final task in value) Text(task.title)],
        ),
        AsyncError(:final error) => Text('$error'),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: MaterialApp(home: _TaskFeature()));
}

class _Task implements SerializableModel {
  const _Task({this.id, required this.title});

  final int? id;
  final String title;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'title': title};
}

DwApiResponse<List<DwModelWrapper>> _tasksResponse(List<_Task> tasks) =>
    DwApiResponse<List<DwModelWrapper>>(
      isOk: true,
      value: tasks
          .map((task) => DwModelWrapper.wrap(model: task))
          .toList(growable: false),
    );
