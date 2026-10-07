import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/core/app_version.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/dartway_example_app.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
export 'package:dartway_client/testing.dart';
export 'package:dartway_example_shared/dartway_example_shared.dart';
export 'package:dartway_push_flutter/testing.dart';

/// The session a signed-in test starts with.
const testSession = DwAuthSession(
  id: 42,
  token: 'token-42',
  isNewAccount: false,
);

const scheduleChannel = DwLiveChannel(DartwayExampleChannel.schedule);
const newsChannel = DwLiveChannel(DartwayExampleChannel.news);
const adminChannel = DwLiveChannel(DartwayExampleChannel.admin);

/// The club as the fake server knows it: the signed-in member, and whatever
/// a test puts on the schedule, in the bookings and in the news.
///
/// Its handlers answer the reads the app makes on its way to any screen, and
/// nothing else: a call a test does not expect is recorded by the fake server
/// as an error, and every test ends asserting there are none.
final class FakeApp {
  FakeApp({UserRole role = UserRole.client, String firstName = 'Vera'})
    : profile = UserProfile(
        id: 7,
        accountId: testSession.id,
        phone: '79990000003',
        firstName: firstName,
        role: role,
        agreedForMarketing: false,
      ) {
    server
      ..registerToken(testSession.token, testSession.id)
      // "My" requests read the caller, as the real handlers do.
      ..onRequest<GetMyProfile>(
        (request, call) => call.accountId == null
            ? const DwNotAuthenticated<UserProfile>()
            : DwCallOk<UserProfile>(profile),
      )
      ..onRequest<ListUpcomingSessions>(
        (request, call) => DwCallOk(<ClubSession>[...sessions]),
      )
      ..onRequest<ListMyBookings>(
        (request, call) => DwCallOk(<SessionBooking>[...bookings]),
      )
      ..onRequest<ListNews>(
        (request, call) => DwCallOk(dwFakeOffsetPage(news, request, call.page)),
      )
      // The push plugin registers the device of a signed-in member.
      ..onCommand<DwRegisterPushToken>(
        (command, call) => const DwCallOk<void>(null),
      )
      // The app's own events, recorded from its first build.
      ..onCommand<DwTrackEvents>((command, call) {
        trackedEvents.addAll(command.events);
        return const DwCallOk<void>(null);
      });
  }

  final server = DwFakeServer(protocol: appProtocol);

  /// The events the app sent.
  final trackedEvents = <DwTrackedEvent>[];

  UserProfile profile;
  final sessions = <ClubSession>[];
  final bookings = <SessionBooking>[];
  final news = <NewsPost>[];

  /// The signed-in member's profile channel, as the server publishes to it.
  DwLiveChannel get profileChannel =>
      DwLiveChannel.forAccount(DartwayExampleChannel.profile, testSession.id);

  /// The signed-in member's bookings channel, as the server publishes to it.
  DwLiveChannel get bookingsChannel =>
      DwLiveChannel.forAccount(DartwayExampleChannel.bookings, testSession.id);
}

/// A running app over a [FakeApp]: the app's own core, built for this
/// test, and the app's own widget.
final class TestApp {
  TestApp._(
    this.fake,
    this.core,
    this.logs,
    this._restoreGlobalHooks,
    this._errorReports,
  );

  final FakeApp fake;
  final DwFlutterCore core;

  /// What `debugPrint` printed while the app ran — the app's error reports
  /// end up here, so a test can assert nothing was reported.
  final List<String> logs;

  DwFakeServer get server => fake.server;

  final void Function() _restoreGlobalHooks;
  final List<DwErrorReport> _errorReports;
  bool _stopped = false;

  /// Unexpected reports not yet explicitly accounted for by this test.
  List<DwErrorReport> get unexpectedErrorReports =>
      List.unmodifiable(_errorReports);

  /// Accounts for exactly this report instance after the test asserts its
  /// error, source and other relevant metadata.
  void consumeErrorReport(DwErrorReport report) {
    final index = _errorReports.indexWhere(
      (candidate) => identical(candidate, report),
    );
    expect(
      index,
      isNonNegative,
      reason: 'the expected error report was not captured by this test',
    );
    if (index >= 0) _errorReports.removeAt(index);
  }

  /// Builds a core against [fake], signed in as [session] (or signed out),
  /// and pumps the app at phone size.
  ///
  /// With [bootstrap], the app is mounted as `DwAppRunner` mounts it — under
  /// the framework's `DwAppBootstrapper`, which runs `dw.init` and puts the
  /// screens that cover the whole app in place — instead of pumping the app
  /// widget over a core started here. [clientOptions] defaults to the fake
  /// server's immediate release delay; pass production options for cache or
  /// navigation lifecycle tests.
  static Future<TestApp> start(
    WidgetTester tester,
    FakeApp fake, {
    DwAuthSession? session = testSession,
    Size size = const Size(390, 844),
    bool bootstrap = false,
    List<DwPushTransportClient> pushTransports = const [],
    DwClientOptions clientOptions = dwFakeClientOptions,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Restored by [stop]: the test binding checks at the end of the body that
    // `debugPrint` is its own again.
    final logs = <String>[];
    final printed = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

    final errorReports = <DwErrorReport>[];
    final previousFlutterError = FlutterError.onError;
    final binding = WidgetsBinding.instance;
    final previousPlatformError = binding.platformDispatcher.onError;
    var globalsRestored = false;
    void restoreGlobalHooks() {
      if (globalsRestored) return;
      globalsRestored = true;
      FlutterError.onError = previousFlutterError;
      binding.platformDispatcher.onError = previousPlatformError;
      debugPrint = printed;
    }

    addTearDown(restoreGlobalHooks);
    final core = AppDwCore.create(
      baseUrl: fake.server.baseUrl,
      appVersion: appBuildVersion,
      httpTransport: fake.server.httpTransport,
      liveConnector: fake.server.liveConnector,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: clientOptions,
      pushTransports: pushTransports,
      analyticsStore: DwMemoryAnalyticsStore(),
      onErrorReport: (report) {
        if (report.error is DwRefusalException ||
            report.error is DwNotAuthenticatedException) {
          return;
        }
        errorReports.add(report);
      },
    );
    // Disposing twice is harmless; this one is for a test that failed before
    // [stop], so the next test can build its own core.
    addTearDown(core.dispose);
    FlutterError.onError = (details) {
      core.handleError(
        details.exception,
        details.stack ?? StackTrace.empty,
        source: DwErrorSource.zone,
      );
      previousFlutterError?.call(details);
    };
    binding.platformDispatcher.onError = (error, stack) {
      core.handleError(error, stack, source: DwErrorSource.zone);
      return true;
    };

    if (bootstrap) {
      await tester.pumpWidget(
        ProviderScope(
          child: DwAppBootstrapper(
            appInitializers: [core.init],
            useNativeSplash: false,
            onError: (error, stackTrace) => logs.add('$error\n$stackTrace'),
            errorScreenBuilder: DwAppLoadingOptions.defaultErrorScreen,
            loadingScreen: const SizedBox.shrink(),
            child: const AppRoot(),
          ),
        ),
      );
    } else {
      await core.init();
      await tester.pumpWidget(const ProviderScope(child: AppRoot()));
    }
    final app = TestApp._(fake, core, logs, restoreGlobalHooks, errorReports);
    addTearDown(() => app.stop(tester));
    await app.settle(tester);
    return app;
  }

  /// Lets the in-memory traffic, Riverpod and a page transition finish.
  ///
  /// Not `pumpAndSettle`: a loading spinner animates for as long as it is on
  /// screen, so settling by frames would wait out its timeout instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  /// Awaits [future] — a call on the core, `core.signOut()` — pumping frames
  /// until it completes.
  ///
  /// A widget test runs on fake time: the fake server's traffic moves only as
  /// frames are pumped, so a plain `await` on such a future never returns.
  /// Fails naming the wait when [future] is still pending after [limit] of
  /// fake time, instead of hanging the test.
  Future<T> run<T>(
    WidgetTester tester,
    Future<T> future, {
    Duration limit = const Duration(seconds: 10),
  }) async {
    var completed = false;
    late T value;
    Object? error;
    StackTrace? stackTrace;
    future.then(
      (result) {
        value = result;
        completed = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stackTrace = s;
        completed = true;
      },
    );
    const step = Duration(milliseconds: 10);
    for (var waited = Duration.zero; !completed; waited += step) {
      if (waited >= limit) {
        fail('the future is still pending after $limit of pumped time');
      }
      await tester.pump(step);
    }
    if (error case final e?) Error.throwWithStackTrace(e, stackTrace!);
    await settle(tester);
    return value;
  }

  /// Taps [finder] and lets everything it set off finish. A notification it
  /// raised stays on screen until [stop] waits it out.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Types [text] into [finder] and lets the app react.
  Future<void> enter(WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await settle(tester);
  }

  /// Waits until the notifications on screen have removed themselves — they
  /// sit over the bottom of the screen, where the buttons are.
  Future<void> waitOutNotifications(WidgetTester tester) async {
    await tester.pump(DwUiNotification.defaultDuration);
    await settle(tester);
  }

  /// Waits out the notifications on screen, unmounts the app and stops the
  /// core, then checks for both unexpected fake-server calls and reports.
  Future<void> stop(WidgetTester tester) async {
    if (_stopped) return;
    Object? cleanupError;
    StackTrace? cleanupStack;
    Future<void> attempt(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStack ??= stackTrace;
      }
    }

    await attempt(() => waitOutNotifications(tester));
    await attempt(() => tester.pumpWidget(const SizedBox()));
    await attempt(() => settle(tester));
    // Its send timer would outlive the test; bounded, so a dispose that
    // stalls fails here instead of hanging the suite.
    await attempt(() => run(tester, core.plugins.analytics.dispose()));
    await attempt(core.dispose);
    await attempt(() async {
      final pendingException = tester.takeException();
      if (pendingException != null &&
          !_errorReports.any(
            (report) => identical(report.error, pendingException),
          )) {
        core.handleError(
          pendingException,
          StackTrace.current,
          source: DwErrorSource.zone,
        );
      }
    });
    _restoreGlobalHooks();
    _stopped = true;
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError!, cleanupStack!);
    }
    expect(server.errors, isEmpty, reason: 'the fake server met a surprise');
    expect(
      _errorReports,
      isEmpty,
      reason:
          'unexpected DartWay error reports were not accounted for: '
          '${_errorReports.map((report) => '${report.source}: ${report.error}').join('; ')}',
    );
  }
}
