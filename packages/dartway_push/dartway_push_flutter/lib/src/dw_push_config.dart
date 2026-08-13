import 'package:flutter_riverpod/misc.dart';

import 'dw_push_notification.dart';
import 'dw_push_provider.dart';

/// How this app does push.
///
/// Everything here is a decision some app makes differently. Nothing in the
/// plugin assumes a platform, a transport, a router, or a moment to ask the
/// user for permission.
final class DwPushConfig {
  const DwPushConfig({
    required this.providers,
    this.recipientIdProvider,
    this.onOpened,
    this.onReceived,
    this.isEnabled,
    this.requestPermissionOnAttach = true,
    this.registerToken,
  });

  /// The transports this app ships, most preferred first.
  ///
  /// The first one that both supports the platform and is available on the
  /// device wins — so declaration order *is* the policy, and there is no
  /// platform switch anywhere in the plugin. An app shipping RuStore on
  /// Android and FCM everywhere else declares `[DwRuStorePush(), DwFirebasePush()]`
  /// and gets exactly that; an app that only knows FCM declares one.
  final List<DwPushClientProvider> providers;

  /// Who the token belongs to, watched for changes.
  ///
  /// Typically `dw.userProfileProvider.select((profile) => profile?.id)`. A
  /// listenable rather than a value because both halves of the pair — token and
  /// user — arrive on their own schedule. Leave it null and drive it yourself
  /// with `dw.plugins.push.setRecipient(...)`.
  final ProviderListenable<int?>? recipientIdProvider;

  /// The user opened a notification. This is where an app routes.
  ///
  /// The plugin deliberately does not navigate: it does not know the app's
  /// router, its guards, or whether the payload even names a screen. It
  /// guarantees only the hard part — that this runs once per tap, after a
  /// frame, whether the app was cold, backgrounded or on screen.
  final void Function(DwPushOpened opened)? onOpened;

  /// A notification arrived while the app was on screen. Optional, and mostly
  /// useful for badges and in-app banners.
  final void Function(DwPushReceived message)? onReceived;

  /// Whether push should run at all in this build. False leaves every transport
  /// untouched: no SDK call, no permission prompt, no token.
  ///
  /// A dev flavour pointed at a staging server is the usual reason.
  final Future<bool> Function()? isEnabled;

  /// Whether to ask for permission as soon as push attaches.
  ///
  /// True is the honest default for an app whose whole point is notifications.
  /// Set it to false to ask at a moment the user understands — after the first
  /// order, at the end of onboarding — and call
  /// `dw.plugins.push.requestPermission()` then.
  final bool requestPermissionOnAttach;

  /// Replaces the call that hands the token to the server.
  ///
  /// The default goes through the module's own CRUD action, which is what an
  /// app on `dartway_push_server` wants. Override it when the backend is
  /// somebody else's, or while migrating off an endpoint of your own.
  final Future<bool> Function({required String token, required String provider})?
  registerToken;
}
