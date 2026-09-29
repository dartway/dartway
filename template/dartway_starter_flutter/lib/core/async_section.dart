import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Renders a live read as a screen section: its data, a skeleton of that data
/// while it loads, and [LoadFailedMessage] when the read was refused or failed.
extension AsyncSection<T> on AsyncValue<T> {
  /// [loadingValue] is stand-in data the loading skeleton is drawn from;
  /// [loadingWidget] replaces the skeleton where drawing [builder] over
  /// stand-in data would itself read something. One of the two is given.
  ///
  /// [onRetry] runs the same read again —
  /// `() => ref.read(dw.request(r).notifier).refetch()`. A refetch, never
  /// `ref.invalidate`: the client keeps a request live for a moment after its
  /// last watcher leaves, so a provider thrown away and rebuilt reattaches to
  /// the same failed state instead of asking again.
  Widget section({
    T? loadingValue,
    Widget? loadingWidget,
    required Future<void> Function() onRetry,
    required Widget Function(T value) builder,
  }) {
    // A section loads with either a loadingValue or a loadingWidget.
    assert((loadingValue == null) != (loadingWidget == null));
    // The session ended under a screen that is on its way out: the sign-in
    // screen is the message, and the read is not an incident to report.
    if (this case AsyncError(error: DwNotAuthenticatedException())) {
      return const SizedBox.shrink();
    }
    return dwBuildAsync(
      loadingValue: loadingValue,
      loadingWidget: loadingWidget,
      childBuilder: builder,
      errorBuilder: (_, _) => _SectionLoadFailed(onRetry: onRetry),
    );
  }
}

/// The kit's [LoadFailedMessage] in the app's language.
class _SectionLoadFailed extends StatelessWidget {
  const _SectionLoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => LoadFailedMessage(
    message: context.l10n.loadFailed,
    retryLabel: context.l10n.retry,
    onRetry: dw.action((_) => onRetry()),
  );
}
