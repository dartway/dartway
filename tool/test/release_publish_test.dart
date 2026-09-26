import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Publishing a plan with pub.dev's `package-created` rate limit as its own
/// case (#313): a short-window answer is retried, a daily-window one defers
/// the package and everything in the plan that depends on it, and the rest
/// of the order still goes out. `attempt` is injected — this never shells
/// out to `dart pub publish` or asks pub.dev anything.
class _Unit implements ReleaseUnit {
  _Unit(this.name, [List<String> dependencies = const []])
    : dependencies = dependencies.toSet();

  @override
  final String name;
  @override
  final Set<String> dependencies;
}

/// A scripted `attempt`: each call for [name] pops the next outcome off its
/// queue, so a test can say exactly "rate-limited, rate-limited, ok" for one
/// package without touching a clock or a process.
class _ScriptedPublisher {
  final Map<String, List<PublishAttempt>> _queued = {};
  final List<String> calls = [];

  void queue(String name, List<PublishAttempt> outcomes) {
    _queued[name] = List.of(outcomes);
  }

  Future<PublishAttempt> call(ReleaseUnit unit) async {
    calls.add(unit.name);
    final queue = _queued[unit.name];
    if (queue == null || queue.isEmpty) {
      throw StateError('no outcome queued for ${unit.name}');
    }
    return queue.length == 1 ? queue.single : queue.removeAt(0);
  }
}

void main() {
  late List<Duration> waits;
  late List<String> log;
  late List<String> visibilityChecked;

  Future<void> fakeWait(Duration d) async => waits.add(d);
  Future<bool> alwaysVisible(ReleaseUnit u) async {
    visibilityChecked.add(u.name);
    return true;
  }

  setUp(() {
    waits = [];
    log = [];
    visibilityChecked = [];
  });

  test('an ordinary success publishes with no retry and no deferral', () async {
    final publisher = _ScriptedPublisher()..queue('a', [const PublishOk()]);
    final report = await publishRelease(
      [_Unit('a')],
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
    );
    expect(report.published, ['a']);
    expect(report.deferred, isEmpty);
    expect(report.stopped, isNull);
    expect(report.isPartial, isFalse);
    expect(waits, isEmpty);
  });

  test('a short-window rate limit is retried and succeeds, without exhausting '
      'the retry budget', () async {
    final publisher = _ScriptedPublisher()
      ..queue('a', [
        const PublishRateLimited(
          PackageCreatedRateLimit(count: 4, window: 'a few minutes'),
        ),
        const PublishRateLimited(
          PackageCreatedRateLimit(count: 4, window: 'a few minutes'),
        ),
        const PublishOk(),
      ]);
    final report = await publishRelease(
      [_Unit('a')],
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
      maxShortWindowRetries: 5,
      shortWindowRetryDelay: const Duration(seconds: 1),
    );
    expect(report.published, ['a']);
    expect(report.deferred, isEmpty);
    expect(publisher.calls, ['a', 'a', 'a']);
    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 1)]);
    expect(log.any((l) => l.contains('Waiting')), isTrue);
  });

  test('a short-window rate limit that never clears is deferred once the retry '
      'budget is spent, not retried forever', () async {
    final publisher = _ScriptedPublisher()
      ..queue(
        'a',
        List.generate(
          10,
          (_) => const PublishRateLimited(
            PackageCreatedRateLimit(count: 4, window: 'a few minutes'),
          ),
        ),
      );
    final report = await publishRelease(
      [_Unit('a')],
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
      maxShortWindowRetries: 2,
      shortWindowRetryDelay: const Duration(seconds: 1),
    );
    expect(report.published, isEmpty);
    expect(report.deferred.keys, ['a']);
    expect(report.deferred['a'], contains('still rate-limited'));
    // First try, then 2 retries: exactly the budget, no more.
    expect(publisher.calls, hasLength(3));
    expect(report.isPartial, isTrue);
  });

  test('a daily rate limit defers the package and every plan entry depending '
      'on it, and still publishes the rest of the order', () async {
    final publisher = _ScriptedPublisher()
      ..queue('dartway_core_shared', [const PublishOk()])
      ..queue('dartway_auth_providers_shared', [
        const PublishRateLimited(
          PackageCreatedRateLimit(count: 12, window: '1 day'),
        ),
      ])
      ..queue('dartway_router', [const PublishOk()]);

    final plan = [
      _Unit('dartway_core_shared'),
      _Unit('dartway_auth_providers_shared', ['dartway_core_shared']),
      _Unit('dartway_auth_providers_server', ['dartway_auth_providers_shared']),
      _Unit('dartway_router'),
    ];

    final report = await publishRelease(
      plan,
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
    );

    expect(report.published, ['dartway_core_shared', 'dartway_router']);
    expect(
      report.deferred.keys,
      containsAll([
        'dartway_auth_providers_shared',
        'dartway_auth_providers_server',
      ]),
    );
    expect(
      report.deferred['dartway_auth_providers_shared'],
      contains("daily package-created limit"),
    );
    expect(
      report.deferred['dartway_auth_providers_server'],
      contains('dartway_auth_providers_shared'),
      reason:
          'a dependent is deferred for depending on the blocked '
          'package, named by name',
    );
    expect(report.isPartial, isTrue);
    // The dependent's own publish is never attempted at all.
    expect(publisher.calls, isNot(contains('dartway_auth_providers_server')));
  });

  test('deferral is transitive through more than one hop: A is daily-limited, '
      'B depends on A, C depends on B (not on A directly) — both B and C are '
      'deferred, and an unrelated D still publishes (review of PR #358, N1: a '
      'mutant that only checks "is this dependency itself rate-limited", '
      'rather than "is this dependency itself deferred", would leave C '
      'published)', () async {
    final publisher = _ScriptedPublisher()
      ..queue('A', [
        const PublishRateLimited(
          PackageCreatedRateLimit(count: 12, window: 'day'),
        ),
      ])
      ..queue('D', [const PublishOk()]);
    final plan = [
      _Unit('A'),
      _Unit('B', ['A']),
      _Unit('C', ['B']),
      _Unit('D'),
    ];

    final report = await publishRelease(
      plan,
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
    );

    expect(report.published, ['D']);
    expect(report.deferred.keys, containsAll(['A', 'B', 'C']));
    expect(
      report.deferred['C'],
      contains('B'),
      reason:
          "C's own reason names B, the dependency it actually has — "
          'not A, which C never depends on directly',
    );
    // Neither B nor C's own `dart pub publish` is ever attempted.
    expect(publisher.calls, ['A', 'D']);
    expect(report.isPartial, isTrue);
  });

  test('a genuine failure stops the run and reports where', () async {
    final publisher = _ScriptedPublisher()
      ..queue('a', [const PublishOk()])
      ..queue('b', [const PublishFailed('boom: sdk lower bound invalid')]);
    final report = await publishRelease(
      [_Unit('a'), _Unit('b'), _Unit('c')],
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
    );
    expect(report.published, ['a']);
    expect(report.stopped, isNotNull);
    expect(report.stopped!.name, 'b');
    expect(report.stopped!.reason, contains('boom'));
    // c is never reached.
    expect(publisher.calls, ['a', 'b']);
    expect(report.isPartial, isTrue);
  });

  test('visibility is confirmed between two publishes, but not after the '
      'last package in the plan', () async {
    final publisher = _ScriptedPublisher()
      ..queue('a', [const PublishOk()])
      ..queue('b', [const PublishOk()]);
    await publishRelease(
      [_Unit('a'), _Unit('b')],
      attempt: publisher.call,
      confirmVisible: alwaysVisible,
      wait: fakeWait,
      log: log.add,
    );
    expect(visibilityChecked, ['a']);
  });

  test('a package failing to become visible stops the run, even though '
      'publishing it succeeded', () async {
    final publisher = _ScriptedPublisher()
      ..queue('a', [const PublishOk()])
      ..queue('b', [const PublishOk()]);
    final report = await publishRelease(
      [_Unit('a'), _Unit('b')],
      attempt: publisher.call,
      confirmVisible: (u) async => false,
      wait: fakeWait,
      log: log.add,
    );
    expect(report.published, ['a']);
    expect(report.stopped, isNotNull);
    expect(report.stopped!.name, 'a');
    expect(publisher.calls, ['a']);
  });

  group('classifyPublishResult', () {
    test('exit code 0 is a success, whatever the output says', () {
      expect(
        classifyPublishResult(
          exitCode: 0,
          stdout: 'Publishing dartway_router 2.0.0 to https://pub.dev\nDone',
          stderr: '',
        ),
        isA<PublishOk>(),
      );
    });

    test('a non-zero exit whose output carries the rate-limit text classifies '
        'as PublishRateLimited, not PublishFailed (review of PR #358, N2)', () {
      final attempt = classifyPublishResult(
        exitCode: 1,
        stdout: 'Uploading...',
        stderr:
            'The "package-created" operation is blocked, as its rate '
            'limit has been reached (4 in the last few minutes).',
      );
      expect(attempt, isA<PublishRateLimited>());
      expect((attempt as PublishRateLimited).limit.count, 4);
    });

    test('a non-zero exit with no rate-limit text is an ordinary failure, and '
        'carries both streams for the report', () {
      final attempt = classifyPublishResult(
        exitCode: 1,
        stdout: 'Publishing dartway_router 2.0.0 to https://pub.dev',
        stderr: 'FormatException: the sdk constraint is invalid',
      );
      expect(attempt, isA<PublishFailed>());
      expect(
        (attempt as PublishFailed).output,
        allOf(
          contains('Publishing dartway_router'),
          contains('FormatException'),
        ),
      );
    });
  });
}
