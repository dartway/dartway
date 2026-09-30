import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/material.dart';

import '../../diagnostics/error_reporting/dw_error_report.dart';
import '../../ui/confirmation/dw_ui_confirmation.dart';

class DwFlutterConfig {
  const DwFlutterConfig({
    this.onErrorReport,
    this.appVersion,
    this.confirmDialogBuilder,
    this.refusalText,
    this.updateRequiredScreen,
    this.readLoadingBuilder,
    this.readFailedBuilder,
  });

  /// Renders a refusal for the user: the project's catalogue, from the code
  /// and parameters the server sent (`DwCallRefusal` carries no sentence).
  ///
  /// `dw.action` shows it when an action is refused — a refused result or a
  /// thrown `DwRefusalException`. Required by `DwFlutterCore`, which cannot
  /// talk to a server whose refusals it cannot show; optional for the toolbox
  /// alone.
  final String Function(DwCallRefusal refusal)? refusalText;

  /// What a read shows while it loads and has no placeholder to draw a
  /// skeleton from — `DwReadBuilder`, `DwPagedListView`, `DwWindowListView`.
  /// The app's kit supplies it once (a skeleton block, an indicator), so no
  /// screen spells its own spinner. Required by `DwFlutterCore`.
  ///
  /// It is also what a list's edge slot shows while the next page loads —
  /// a slot 48 pixels high — so it sizes itself to the room it is given: a
  /// centred indicator, not a block of fixed height.
  final WidgetBuilder? readLoadingBuilder;

  /// What a read shows when it did not answer with data and no branch of its
  /// own took the answer: the app's kit view, with a way to ask again.
  ///
  /// [error] is a `DwRefusalException` without an `onRefused` branch, a
  /// `DwFailedException` or a `DwTimeoutException`; `retry` runs the same
  /// read again and completes when it is answered. A signed-out read never
  /// reaches it — the sign-in screen is the message. Required by
  /// `DwFlutterCore`: a read that fails into nothing reads as "there is
  /// nothing here", which is a lie.
  final Widget Function(
    BuildContext context,
    Object error,
    Future<void> Function() retry,
  )?
  readFailedBuilder;

  /// The full-screen page shown over the app once this build can no longer
  /// talk to its server — `dw.updateRequired` (the build is below the
  /// server's minimum) or `dw.protocolUnsupported` (a framework version
  /// skew); the refusal says which.
  ///
  /// The project supplies the words and the store links: the framework knows
  /// neither the app's language nor where it is published. The bootstrapper
  /// (`DwAppRunner`) puts it in place of the app, since nothing under it can
  /// reach the server any more. Built above the app's `MaterialApp`, so the
  /// page brings its own (a `MaterialApp` of its own is the usual shape).
  /// Without it the app stays on screen and every call answers the refusal.
  final Widget Function(BuildContext context, DwCallRefusal refusal)?
  updateRequiredScreen;

  /// Called for every reported error with its full [DwErrorReport] — the error
  /// itself plus the app-state context snapshot (route, mounted features,
  /// action, platform, version, user). When unset, the error is logged via
  /// `debugPrint` and nothing else happens — set this to alert on it.
  final void Function(DwErrorReport report)? onErrorReport;

  /// The app build, `<semver>+<build>` (`1.4.2+57`): shown in error reports
  /// and, with the data layer, sent to the server on every call so it can
  /// refuse a build below its minimum. Required by `DwFlutterCore`.
  final String? appVersion;

  /// Custom confirmation UI for `dw.action(confirmation: ...)`. Defaults to
  /// the built-in `DwConfirmDialog`.
  final Future<bool?> Function(
    BuildContext context,
    DwUiConfirmation confirmation,
  )?
  confirmDialogBuilder;
}
