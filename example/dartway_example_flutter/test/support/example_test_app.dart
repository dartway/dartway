import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/app_version.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/dartway_example_app.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_client/testing.dart';
export 'package:dartway_example_shared/dartway_example_shared.dart';
export 'package:dartway_push_flutter/testing.dart';

/// The session a signed-in test starts with.
const testSession = DwAuthSession(
  id: 42,
  token: 'token-42',
  isNewAccount: false,
);

const scheduleChannel = DwLiveChannel(ExampleChannel.schedule);
const newsChannel = DwLiveChannel(ExampleChannel.news);
const adminChannel = DwLiveChannel(ExampleChannel.admin);

/// The club as the fake server knows it: the signed-in member, and whatever
/// a test puts on the schedule, in the bookings and in the news.
///
/// Its handlers answer the reads the app makes on its way to any screen, and
/// nothing else: a call a test does not expect is recorded by the fake server
/// as an error, and every test ends asserting there are none.
final class FakeClub {
  FakeClub({UserRole role = UserRole.client, String firstName = 'Vera'})
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
      ..onRequest<ListNews>((request, call) => DwCallOk(<NewsPost>[...news]))
      // The push plugin registers the device of a signed-in member.
      ..onCommand<DwRegisterPushToken>(
        (command, call) => const DwCallOk<void>(null),
      );
  }

  final server = DwFakeServer(protocol: exampleProtocol);

  UserProfile profile;
  final sessions = <ClubSession>[];
  final bookings = <SessionBooking>[];
  final news = <NewsPost>[];

  /// The signed-in member's profile channel, as the server publishes to it.
  DwLiveChannel get profileChannel =>
      DwLiveChannel.forAccount(ExampleChannel.profile, testSession.id);

  /// The signed-in member's bookings channel, as the server publishes to it.
  DwLiveChannel get bookingsChannel =>
      DwLiveChannel.forAccount(ExampleChannel.bookings, testSession.id);
}

/// A running example app over a [FakeClub]: the app's own core, built for this
/// test, and the app's own widget.
final class ExampleTestApp {
  ExampleTestApp._(this.club, this.core, this.logs, this._debugPrint);

  final FakeClub club;
  final DwFlutterCore core;

  /// What `debugPrint` printed while the app ran — the app's error reports
  /// end up here, so a test can assert nothing was reported.
  final List<String> logs;

  DwFakeServer get server => club.server;

  final DebugPrintCallback _debugPrint;

  /// Builds a core against [club], signed in as [session] (or signed out),
  /// and pumps the app at phone size.
  ///
  /// With [bootstrap], the app is mounted as `DwAppRunner` mounts it — under
  /// the framework's `DwAppBootstrapper`, which runs `dw.init` and puts the
  /// screens that cover the whole app in place — instead of pumping the app
  /// widget over a core started here.
  static Future<ExampleTestApp> start(
    WidgetTester tester,
    FakeClub club, {
    DwAuthSession? session = testSession,
    Size size = const Size(390, 844),
    bool bootstrap = false,
    List<DwPushTransportClient> pushTransports = const [],
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

    final core = ExampleDwCore.create(
      baseUrl: club.server.baseUrl,
      appVersion: exampleAppVersion,
      httpTransport: club.server.httpTransport,
      liveConnector: club.server.liveConnector,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: dwFakeClientOptions,
      pushTransports: pushTransports,
    );
    // Disposing twice is harmless; this one is for a test that failed before
    // [stop], so the next test can build its own core.
    addTearDown(core.dispose);

    if (bootstrap) {
      await tester.pumpWidget(
        ProviderScope(
          child: DwAppBootstrapper(
            appInitializers: [core.init],
            useNativeSplash: false,
            onError: (error, stackTrace) => logs.add('$error\n$stackTrace'),
            errorScreenBuilder: DwAppLoadingOptions.defaultErrorScreen,
            loadingScreen: const SizedBox.shrink(),
            child: const ExampleApp(),
          ),
        ),
      );
    } else {
      await core.init();
      await tester.pumpWidget(const ProviderScope(child: ExampleApp()));
    }
    final app = ExampleTestApp._(club, core, logs, printed);
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

  /// Taps [finder] and lets everything it set off finish. A notification it
  /// raised stays on screen until [stop] waits it out.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  /// Waits until the notifications on screen have removed themselves — they
  /// sit over the bottom of the screen, where the buttons are.
  Future<void> waitOutNotifications(WidgetTester tester) async {
    await tester.pump(DwUiNotification.defaultDuration);
    await settle(tester);
  }

  /// Waits out the notifications on screen, unmounts the app and stops the
  /// core, asserting that the fake server met nothing unexpected.
  Future<void> stop(WidgetTester tester) async {
    await waitOutNotifications(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await core.dispose();
    debugPrint = _debugPrint;
    expect(server.errors, isEmpty, reason: 'the fake server met a surprise');
  }
}
