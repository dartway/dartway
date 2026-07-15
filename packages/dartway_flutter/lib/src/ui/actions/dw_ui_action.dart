import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

/// A UI-aware async action: confirmation → run → notify → follow-up → error
/// report, all in one value.
///
/// Create one through [DwFlutter.action] — `dw.action(...)` — never directly:
/// the action's work is woven into the ambient `dw` services (it calls
/// `dw.confirm`, `dw.notify`, `dw.handleError`), so its factory lives on `dw`.
/// The type itself is public — a `DwUiAction` is a value you store, pass around
/// and hand to a [DwActionBuilder] or an `onTap`.
class DwUiAction<T> {
  const DwUiAction._(this._execute);

  final Future<T?> Function(BuildContext context) _execute;

  /// Runs the action in a given [context].
  Future<T?> call(BuildContext context) => _execute(context);
}

/// The single public entry point for building a [DwUiAction] — `dw.action(...)`.
extension DwActionExtension on DwFlutter {
  DwUiAction<T> action<T>(
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
        final confirmed = await confirm(context, confirmation);
        // Declined (or the dialog was dismissed): no action, no notifications,
        // no follow-up.
        if (confirmed != true || !context.mounted) return null;
      }

      try {
        final value = await action(context);

        if (onSuccessNotification != null) {
          notify.success(onSuccessNotification);
        }

        if (customNotificationBuilder != null) {
          final customNotification = await customNotificationBuilder(value);
          if (customNotification != null) {
            notify.custom(customNotification);
          }
        }

        if (followUpIfMountedAction != null && context.mounted) {
          await followUpIfMountedAction(context, value);
        }

        return value;
      } catch (error, stackTrace) {
        if (onErrorNotification != null) {
          notify.error(onErrorNotification);
        }
        onError?.call(error, stackTrace);
        handleError(
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
