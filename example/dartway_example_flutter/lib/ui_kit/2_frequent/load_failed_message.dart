part of '../ui_kit.dart';

/// What a section shows when its read did not answer — a sentence and a way out
/// of it.
///
/// `dwBuildAsync` defaults its error widget to `SizedBox.shrink()`, which is
/// correct for a decoration and wrong for the section its screen exists for:
/// an empty page already means "nothing has been created yet", and a failed
/// read means "go and look at the backend". Sections get this through the
/// app's `section(...)` extension in `lib/core/`, so none of them can forget
/// it.
///
/// The texts are the app's, handed in: the kit knows no language.
class LoadFailedMessage extends StatelessWidget {
  const LoadFailedMessage({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  /// The sentence saying the read failed.
  final String message;

  /// The label of the retry button.
  final String retryLabel;

  /// Asks the failed read again.
  final DwUiAction<void> onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText.body(message, textAlign: TextAlign.center),
        AppButton.text(retryLabel, onTap: onRetry),
      ],
    ),
  );
}
