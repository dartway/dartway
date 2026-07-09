import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';

/// UI-aware async action with error handling, notifications,
/// and follow-up callbacks.
/// Always requires a [BuildContext].
class DwUiAction<T> {
  final Future<T?> Function(BuildContext context) _execute;

  const DwUiAction._(this._execute);

  /// Runs the action in a given [context].
  Future<T?> call(BuildContext context) => _execute(context);

  factory DwUiAction.create(
    FutureOr<T> Function(BuildContext context) action, {
    String? label,
    DwUiConfirmation? confirmation,
    String? onSuccessNotification,
    String? onErrorNotification,
    FutureOr<DwUiNotification?> Function(T value)? customNotificationBuilder,
    FutureOr<void> Function(BuildContext context, T value)?
    followUpIfMountedAction,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return DwUiAction._((context) async {
      if (confirmation != null) {
        final confirmed = await dw.confirm(context, confirmation);
        // Declined (or the dialog was dismissed): no action, no notifications,
        // no follow-up.
        if (confirmed != true || !context.mounted) return null;
      }

      try {
        final value = await action(context);

        if (onSuccessNotification != null) {
          dw.notify.success(onSuccessNotification);
        }

        if (customNotificationBuilder != null) {
          final customNotification = await customNotificationBuilder(value);
          if (customNotification != null) {
            dw.notify.custom(customNotification);
          }
        }

        if (followUpIfMountedAction != null && context.mounted) {
          await followUpIfMountedAction(context, value);
        }

        return value;
      } catch (error, stackTrace) {
        if (onErrorNotification != null) {
          dw.notify.error(onErrorNotification);
        }
        onError?.call(error, stackTrace);
        dw.handleError(
          error,
          stackTrace,
          source: DwErrorSource.uiAction,
          // Actions rarely get explicit labels — the notification texts make
          // a meaningful fallback name in error reports.
          actionLabel: label ?? onErrorNotification ?? onSuccessNotification,
        );
        return null;
      }
    });
  }
}
