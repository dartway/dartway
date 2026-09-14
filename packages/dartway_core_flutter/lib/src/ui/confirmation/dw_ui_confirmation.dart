import 'package:flutter/material.dart';

/// Declarative confirmation shown before a `DwUiAction` runs — replaces the
/// hand-rolled `showDialog<bool>` boilerplate around destructive actions.
class DwUiConfirmation {
  const DwUiConfirmation(
    this.message, {
    this.title,
    this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
  });

  final String message;
  final String? title;

  /// Defaults to [MaterialLocalizations.okButtonLabel].
  final String? confirmLabel;

  /// Defaults to [MaterialLocalizations.cancelButtonLabel].
  final String? cancelLabel;

  /// Renders the confirm button in the error color.
  final bool isDestructive;
}

/// The built-in confirmation dialog; used when the app has not supplied
/// `DwConfig.confirmDialogBuilder`.
abstract final class DwConfirmDialog {
  static Future<bool?> show(
    BuildContext context,
    DwUiConfirmation confirmation,
  ) {
    final localizations = MaterialLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: confirmation.title != null ? Text(confirmation.title!) : null,
          content: Text(confirmation.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                confirmation.cancelLabel ?? localizations.cancelButtonLabel,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: confirmation.isDestructive
                  ? TextButton.styleFrom(foregroundColor: colorScheme.error)
                  : null,
              child: Text(
                confirmation.confirmLabel ?? localizations.okButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}
