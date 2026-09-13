import 'package:dartway_client/testing.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/dartway_example_app.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_client/testing.dart';
export 'package:dartway_example_shared/dartway_example_shared.dart';

/// The session a signed-in test starts with.
const testSession = DwSession(id: 42, token: 'token-42', isNewAccount: false);

const scheduleChannel = DwChannel(ExampleChannel.schedule);
const newsChannel = DwChannel(ExampleChannel.news);

/// The club as the fake server knows it: the signed-in member, and whatever
/// a test puts on the schedule, in the bookings and in the news.
///
/// Its handlers answer the reads the app makes on its way to any screen, and
/// nothing else: a command a test does not expect is recorded by the fake
/// server as an error, and every test ends asserting there are none.
final class FakeClub {
  FakeClub({UserRole role = UserRole.client, String firstName = 'Vera'})
    : profile = ProfileView(
        id: 7,
        phone: '79990000003',
        firstName: firstName,
        role: role,
        agreedForMarketing: false,
      ) {
    server
      ..registerToken(testSession.token, testSession.id)
      ..onRequest<GetMyProfile>(
        (request, call) => call.accountId == request.accountId
            ? DwOk<ProfileView?>(profile)
            : DwRefused(DwRefusal(DwCoreRefusal.forbidden)),
      )
      ..onRequest<ListUpcomingSessions>(
        (request, call) => DwOk(<ClubSessionView>[...sessions]),
      )
      ..onRequest<ListMyBookings>(
        (request, call) => DwOk(<BookingView>[...bookings]),
      )
      ..onRequest<ListNews>((request, call) => DwOk(<NewsPostView>[...news]));
  }

  final server = DwFakeServer(protocol: dartwayExampleProtocol);

  ProfileView profile;
  final sessions = <ClubSessionView>[];
  final bookings = <BookingView>[];
  final news = <NewsPostView>[];

  DwChannel get profileChannel =>
      DwChannel(ExampleChannel.profile, testSession.id);

  DwChannel get bookingsChannel =>
      DwChannel(ExampleChannel.bookings, profile.id);
}

/// A running example app over a [FakeClub]: the app's own core, built for this
/// test, and the app's own widget.
final class ExampleTestApp {
  ExampleTestApp._(this.club, this.core, this.logs, this._debugPrint);

  final FakeClub club;
  final DwCore core;

  /// What `debugPrint` printed while the app ran — the app's error reports
  /// end up here, so a test can assert nothing was reported.
  final List<String> logs;

  DwFakeServer get server => club.server;

  final DebugPrintCallback _debugPrint;

  /// Builds a core against [club], signed in as [session] (or signed out),
  /// and pumps the app at phone size.
  static Future<ExampleTestApp> start(
    WidgetTester tester,
    FakeClub club, {
    DwSession? session = testSession,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Restored by [stop]: the test binding checks at the end of the body that
    // `debugPrint` is its own again.
    final logs = <String>[];
    final printed = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

    final core = createExampleDwCore(
      endpoint: club.server.endpoint,
      connector: club.server.connector,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: const DwClientOptions(
        releaseDelay: Duration.zero,
        reconnectDelay: Duration(milliseconds: 1),
      ),
    );
    // Disposing twice is harmless; this one is for a test that failed before
    // [stop], so the next test can build its own core.
    addTearDown(core.dispose);
    await core.init();

    await tester.pumpWidget(const ProviderScope(child: ExampleApp()));
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
