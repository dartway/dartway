import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/core/app_version.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/dartway_starter_app.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_client/testing.dart';
export 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The session a signed-in test starts with.
const testSession = DwAuthSession(
  id: 42,
  token: 'token-42',
  isNewAccount: false,
);

const adminChannel = DwLiveChannel(DartwayStarterChannel.admin);
const settingsChannel = DwLiveChannel(DartwayStarterChannel.settings);

/// The signed-in member's own profile channel, as the server publishes to it.
final profileChannel = DwLiveChannel.forAccount(
  DartwayStarterChannel.profile,
  testSession.id,
);

/// The server as a widget test knows it: the signed-in member and the stored
/// settings, answered the way the real handlers answer them.
///
/// Its handlers answer the reads the app makes on its way to any screen and
/// the member's own profile edits, and nothing else: a call a test does not
/// expect is recorded by the fake server as an error, and every test ends
/// asserting there are none.
final class FakeApp {
  FakeApp({
    UserRole role = UserRole.user,
    String firstName = 'Vera',
    String? phone = '79990000002',
    String? email,
  }) : profile = UserProfile(
         id: 7,
         accountId: testSession.id,
         firstName: firstName,
         phone: phone,
         email: email,
         role: role,
         joinedAt: DateTime.utc(2026, 9, 1),
       ) {
    server
      ..registerToken(testSession.token, testSession.id)
      // "My" requests read the caller, as the real handlers do.
      ..onRequest<GetMyProfile>(
        (request, call) => call.accountId == null
            ? const DwNotAuthenticated<UserProfile>()
            : DwCallOk<UserProfile>(profile),
      )
      ..onRequest<ListAppSettings>(
        (request, call) => DwCallOk(<AppSetting>[...settings]),
      )
      ..onCommand<UpdateMyProfile>((command, call) {
        profile = profile.copyWith(
          firstName: command.firstName,
          lastName: command.lastName,
          gender: command.gender,
          avatarUrl: switch (command.avatarFileId) {
            DwSetField(:final value) => DwFieldPatch.set(avatarUrls[value]!),
            DwClearField() => const DwFieldPatch.clear(),
            _ => const DwFieldPatch.keep(),
          },
        );
        call.publish(profileChannel, [profile]);
        return DwCallOk(profile);
      });
  }

  final server = DwFakeServer(protocol: dartwayStarterProtocol);

  UserProfile profile;
  final settings = <AppSetting>[];

  /// Public URLs of the files a `DwFakeStorage` confirmed, by id.
  final Map<int, String> avatarUrls = {};
}

/// A running app over a [FakeApp]: the app's own core, built for this test,
/// and the app's own widget.
final class TestApp {
  TestApp._(this.fake, this.core, this.logs, this._debugPrint);

  final FakeApp fake;
  final DwFlutterCore core;

  /// What `debugPrint` printed while the app ran — the app's error reports end
  /// up here, so a test can assert nothing was reported.
  final List<String> logs;

  DwFakeServer get server => fake.server;

  final DebugPrintCallback _debugPrint;

  /// Builds a core against [fake], signed in as [session] (or signed out), and
  /// pumps the app at phone size.
  ///
  /// With [bootstrap], the app is mounted as `DwAppRunner` mounts it — under
  /// the framework's `DwAppBootstrapper`, which runs `dw.init` and puts the
  /// screens that cover the whole app in place — instead of pumping the app
  /// widget over a core started here. [storageTransport] carries uploads to a
  /// `DwFakeStorage`.
  static Future<TestApp> start(
    WidgetTester tester,
    FakeApp fake, {
    DwAuthSession? session = testSession,
    Size size = const Size(390, 844),
    bool bootstrap = false,
    DwStorageTransport? storageTransport,
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

    final core = createAppDwCore(
      baseUrl: fake.server.baseUrl,
      appVersion: appBuildVersion,
      httpTransport: fake.server.httpTransport,
      liveConnector: fake.server.liveConnector,
      storageTransport: storageTransport,
      tokenStore: DwMemoryTokenStore(session),
      clientOptions: dwFakeClientOptions,
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
            child: const AppRoot(),
          ),
        ),
      );
    } else {
      await core.init();
      await tester.pumpWidget(const ProviderScope(child: AppRoot()));
    }
    final app = TestApp._(fake, core, logs, printed);
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
