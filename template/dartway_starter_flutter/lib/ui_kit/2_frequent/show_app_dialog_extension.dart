part of '../ui_kit.dart';

/// The kit's dialog: a screen opens one through this and never through
/// `showDialog` — `dartway check` refuses it outside `ui_kit/`
/// (`forbiddenNavigationCall`), so the frame of every dialog is decided here.
///
/// A question before an action is not a dialog of its own:
/// `dw.action(…, confirmation: DwUiConfirmation(…))`.
extension ShowAppDialogExtension on BuildContext {
  /// Shows [child] in the kit's dialog frame; completes with what it pops
  /// with — `Navigator.of(context).pop(value)`.
  Future<T?> showAppDialog<T>({required Widget child}) => showDialog<T>(
    context: this,
    builder: (_) => Dialog(clipBehavior: Clip.antiAlias, child: child),
  );
}
