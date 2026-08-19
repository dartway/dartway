import 'package:dartway_starter_client/dartway_starter_client.dart';
// Prefixed because this project's generated client and the DartWay core each
// declare a `Protocol`, and the core's arrives through the framework barrel.
import 'package:dartway_starter_client/dartway_starter_client.dart' as app;
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/default_models.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
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
/// [resetTestCore] to start from nothing recorded and nothing prepared.
///
/// It is handed this project's own generated `Protocol()` — the same object the
/// real Serverpod client carries — so every model is named on the wire exactly
/// as the server knows it. Nothing else can do that job: a generated model is
/// an abstract class with a private implementation, and its `runtimeType` reads
/// `_AppSettingImpl`.
final testTransport = DwRecordingServerTransport(
  serializationManager: app.Protocol(),
);

/// Boots this app's core, once, through the app's own initializer.
///
/// Call it from `setUpAll`. It is the real bootstrap with one thing swapped —
/// the server — so a test never stands a second, subtly different core beside
/// the one the app ships. The initializer is idempotent, so no test file has to
/// know whether another one got there first.
///
/// The core is *required* to render, not only to interact: a feature builds its
/// `dw.action(...)` inside `build`, so `dw` is touched before anything is
/// tapped. A test that forgets this fails at a finder ("found 0 widgets") with
/// the real cause in a separate exception block above it.
void bootTestCore() {
  initExampleDwCore(transport: testTransport);
  // What `dw.initDwCore` does for the repository, without the session and
  // socket startup a test has no server to do it against. List skeletons need
  // this part: `dwBuildListAsync` builds its placeholder from the registered
  // default model.
  DefaultModels.initRepository();
}

/// Forgets everything the transport recorded and every answer prepared for it.
/// Call from `setUp`.
void resetTestCore() => testTransport.reset();

/// A signed-in admin, for the screens that are only shown to one.
UserProfile adminProfile({int id = 1, String firstName = 'Alex'}) =>
    UserProfile(
      id: id,
      userIdentifier: '7900000000$id',
      firstName: firstName,
      phone: '7900000000$id',
      role: UserRole.admin,
      agreedForMarketingCommunications: false,
      conditionsAcceptedAt: DateTime.utc(2026),
    );

extension AppFeaturePump on WidgetTester {
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

  /// Pumps [child] inside everything a page of this app is drawn inside, minus
  /// the router: localizations, the notification listener, and a Riverpod scope.
  ///
  /// [signedInAs] overrides the framework's profile providers. Overriding them
  /// in the test's own `ProviderScope` is the sanctioned way to stand a user up
  /// — there is no session here to sign into, and inventing one would test the
  /// framework's session rather than this feature.
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
          home: DwNotificationsListener(
            handlers: {DwUiNotification: DwUiNotificationHandler()},
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Wraps [models] the way the server would answer a `getAll` with them.
DwApiResponse<List<DwModelWrapper>> listResponse(
  List<SerializableModel> models,
) => DwApiResponse<List<DwModelWrapper>>(
  isOk: true,
  value: models
      .map((model) => DwModelWrapper.wrap(model: model))
      .toList(growable: false),
);
