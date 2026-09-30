part of '../ui_kit.dart';

/// What a read shows when it did not answer — a sentence and a way out of it.
///
/// The app's `DwFlutterConfig.readFailedBuilder` (`lib/core/dw_core.dart`), so
/// every `DwReadBuilder` shows it and none can forget to: an empty page means
/// "nothing has been created yet", and a failed read must not look like one.
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
