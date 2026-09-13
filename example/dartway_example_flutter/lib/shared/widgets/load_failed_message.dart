import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What a section shows when its read did not answer — a sentence and a way out
/// of it.
///
/// `dwBuildAsync` defaults its error widget to `SizedBox.shrink()`, which is
/// correct for a decoration and wrong for the section its screen exists for:
/// an empty page already means "nothing has been created yet", and a failed
/// read means "go and look at the backend". Sections get this through
/// [AsyncSection.section], so none of them can forget it.
///
/// The framework ships no widget of this kind on purpose: the copy is
/// user-visible and has to come from `context.l10n`, which a package cannot
/// own.
class LoadFailedMessage extends StatelessWidget {
  const LoadFailedMessage({required this.onRetry, super.key});

  /// Asks the failed read again.
  final DwUiAction<void> onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.body(context.l10n.loadFailed, textAlign: TextAlign.center),
        AppButton.text(context.l10n.retry, onTap: onRetry),
      ],
    ),
  );
}

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
    assert(
      (loadingValue == null) != (loadingWidget == null),
      'A section loads with either a loadingValue or a loadingWidget.',
    );
    // The session ended under a screen that is on its way out: the sign-in
    // screen is the message, and the read is not an incident to report.
    if (this case AsyncError(error: DwNotAuthenticatedException())) {
      return const SizedBox.shrink();
    }
    return dwBuildAsync(
      loadingValue: loadingValue,
      loadingWidget: loadingWidget,
      childBuilder: builder,
      errorBuilder: (_, _) =>
          LoadFailedMessage(onRetry: dw.action((_) => onRetry())),
    );
  }
}
