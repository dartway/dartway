import 'package:dartway_example_client/dartway_example_client.dart';
// Prefixed because both this project's generated client and the DartWay core's
// declare a `Protocol`, and the core's arrives through the framework barrel.
import 'package:dartway_example_client/dartway_example_client.dart' as app;
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/default_models.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_serverpod_core_flutter/testing.dart'
    show DwRecordingServerTransport, DwUnpreparedServerCall;

/// The server, as far as any widget test in this project is concerned.
///
/// One instance for the whole run: the core keeps the transport it was built
/// with for its lifetime, and there is one core per process. Each test calls
/// [resetExampleTestCore] to start from nothing recorded and nothing prepared.
///
/// It is handed this project's own generated `Protocol()` — the same object the
/// real Serverpod client carries — so every model is named on the wire exactly
/// as the server knows it. Nothing else can do that job: a generated model is
/// an abstract class with a private implementation, and its `runtimeType` reads
/// `_NewsPostImpl`.
final exampleTransport = DwRecordingServerTransport(
  serializationManager: app.Protocol(),
);

/// Boots the app's own core, once, through the app's own initializer.
///
/// Call it from `setUpAll`. It is the app's real bootstrap with one thing
/// swapped — the server — so a test never rebuilds a second, subtly different
/// core beside the one the app ships. The initializer is idempotent, so no test
/// file has to know whether another one got there first.
///
/// The core is *required* to render, not only to interact: a feature builds its
/// `dw.action(...)` inside `build`, so `dw` is touched before anything is
/// tapped. A test that forgets this fails at a finder ("found 0 widgets") with
/// the real cause in a separate exception block above it.
void bootExampleTestCore() {
  initExampleDwCore(transport: exampleTransport);
  // What `dw.initDwCore` would do for the repository, without the session and
  // socket startup that a test has no server to do it against. This is the part
  // list skeletons need: `dwBuildListAsync` builds its placeholder from the
  // registered default model.
  DefaultModels.initRepository();
}

/// Forgets everything the transport recorded and every answer prepared for it.
/// Call from `setUp`.
void resetExampleTestCore() => exampleTransport.reset();

/// A signed-in staff member, for the features that are only shown to one.
UserProfile staffProfile({int id = 7, String firstName = 'Sam'}) => UserProfile(
  id: id,
  userIdentifier: '7900000000$id',
  firstName: firstName,
  phone: '7900000000$id',
  role: UserRole.staff,
  agreedForMarketingCommunications: false,
  conditionsAcceptedAt: DateTime.utc(2026),
);

/// Pumps [child] inside everything a page of this app is drawn inside, minus
/// the router: localizations, the theme, the notification listener, and a
/// Riverpod scope.
///
/// [signedInAs] overrides the framework's profile providers. Overriding them in
/// the test's own `ProviderScope` is the sanctioned way to stand a user up —
/// there is no session here to sign into, and inventing one would test the
/// framework's session rather than this feature.
extension ExampleFeaturePump on WidgetTester {
  /// Taps [finder] and lets everything the tap set off finish.
  ///
  /// `pumpAndSettle` alone is not enough after an action that notifies: a
  /// successful `dw.action(onSuccessNotification: ...)` inserts a toast which
  /// removes itself on a `Future.delayed`, and settling waits for frames, not
  /// for timers. A test that stops early ends on "A Timer is still pending even
  /// after the widget tree was disposed" — an error about the toast, in a test
  /// about a save.
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
    await pump(DwUiNotification.defaultDuration);
  }

  Future<void> pumpFeature(Widget child, {UserProfile? signedInAs}) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          if (signedInAs != null) ...[
            dw.userProfileProvider.overrideWithValue(signedInAs),
            dw.requireUserProfileProvider.overrideWithValue(signedInAs),
          ],
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Explicit, and not a detail: left out, the tree resolves against the
          // locale of the machine running the test, so `find.text('Save')`
          // asserts on whichever language that machine happened to pick. The
          // suite then passes for whoever wrote it and fails for the next
          // person to clone the repository, with a diff that mentions no
          // locale. Pin it to the language the assertions are written in.
          locale: const Locale('en'),
          home: DwNotificationsListener(
            handlers: {DwUiNotification: DwUiNotificationHandler()},
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }
}

/// Wraps [posts] the way the server would answer a `getAll` with them.
DwApiResponse<List<DwModelWrapper>> newsPostsResponse(List<NewsPost> posts) =>
    DwApiResponse<List<DwModelWrapper>>(
      isOk: true,
      value: posts
          .map((post) => DwModelWrapper.wrap(model: post))
          .toList(growable: false),
    );

/// A post as the server would hand it back — anything a list needs to draw.
NewsPost newsPost({
  int id = 1,
  String title = 'Pool closed on Monday',
  String text = 'Maintenance day.',
}) => NewsPost(
  id: id,
  authorProfileId: 7,
  title: title,
  text: text,
  createdAt: DateTime.utc(2026, 8, 19),
);
