import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/logic/dw_flutter_config.dart';
import '../../diagnostics/error_reporting/dw_error_report.dart';
import '../../private/dw_singleton.dart';

/// What a screen shows for one refusal code of a read — the refusal is
/// passed in for its parameters.
typedef DwRefusedBuilder =
    Widget Function(BuildContext context, DwCallRefusal refusal);

/// The branches every read on screen shares — `DwReadBuilder`,
/// `DwPagedListView` and `DwWindowListView` — for the answers that are not data: loading, a
/// refusal with a branch of its own, a signed-out read, and everything else
/// as the app's retryable view. One implementation, so the three agree.
abstract final class DwReadStates {
  /// While a read loads: [placeholder] drawn as a skeleton when there is
  /// one, the app's `DwFlutterConfig.readLoadingBuilder` otherwise.
  static Widget loading(BuildContext context, {Widget? placeholder}) {
    if (placeholder == null) return _config.readLoadingBuilder!(context);
    // A sliver child needs the sliver-flavoured skeletonizer: the box one
    // would be an invalid child for the enclosing CustomScrollView.
    if (placeholder is SliverList ||
        placeholder is SliverGrid ||
        placeholder is SliverToBoxAdapter ||
        placeholder is SliverPadding) {
      return SliverSkeletonizer(enabled: true, child: placeholder);
    }
    return Skeletonizer(child: placeholder);
  }

  /// When a read ended short of data.
  ///
  /// A signed-out read shows nothing: the session ended under a screen on
  /// its way out, and the sign-in screen is the message. A refusal whose code
  /// [onRefused] names shows that branch. Everything else is the app's
  /// `DwFlutterConfig.readFailedBuilder` with [retry]. A failure — not a
  /// refusal, which is an answer for the person, and not a server out of
  /// reach, which the client keeps asking — is reported once.
  static Widget failed(
    BuildContext context,
    Object error,
    StackTrace stackTrace, {
    required Future<void> Function() retry,
    Map<DwRefusalCode, DwRefusedBuilder> onRefused = const {},
  }) {
    switch (error) {
      case DwNotAuthenticatedException():
        return const SizedBox.shrink();
      case DwRefusalException(:final refusal):
        for (final MapEntry(key: code, value: branch) in onRefused.entries) {
          if (refusal.isCode(code)) return branch(context, refusal);
        }
      case DwTimeoutException():
        break;
      default:
        _reportOnce(error, stackTrace);
    }
    return _config.readFailedBuilder!(context, error, retry);
  }

  /// The slot past the loaded rows of a list at an end that has more: the
  /// app's `readLoadingBuilder` while [loading], a retry after [error], empty
  /// while idle. One height whatever it shows, so the slot changing moves no
  /// row; nothing while nothing loads, so nothing animates off screen.
  static Widget edge(
    BuildContext context, {
    required bool loading,
    required Object? error,
    required VoidCallback retry,
  }) => SizedBox(
    height: 48,
    child: error != null
        ? Center(
            child: IconButton(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
            ),
          )
        : loading
        ? _config.readLoadingBuilder!(context)
        : null,
  );

  static DwFlutterConfig get _config => dw.config;

  /// Errors already reported. A read's error is one object for as long as
  /// its state stands, and a screen rebuilds many times over it.
  static final _reported = Expando<bool>('dw read reported');

  static void _reportOnce(Object error, StackTrace stackTrace) {
    final keyable = error is! String && error is! num && error is! bool;
    if (keyable) {
      if (_reported[error] ?? false) return;
      _reported[error] = true;
    }
    dw.handleError(
      error,
      stackTrace,
      source: DwErrorSource.asyncBuild,
      failedCall: error is DwFailedException ? error.call : null,
    );
  }
}
