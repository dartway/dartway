import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

/// A UI-aware async action: confirmation → run → notify → follow-up → error
/// report, all in one value.
///
/// **Results are understood.** An action that returns a [DwCallResult] — as
/// `(context) => dw.command(...)` does — succeeds only on [DwCallOk]; any other
/// result is treated as its exception (`valueOrThrow`) and handled below. The
/// caller never has to unwrap a result to get the refusal shown.
///
/// A refusal — a [DwCallRefused] result, or a [DwRefusalException] thrown by the
/// app's own code — is shown to the user through [DwConfig.refusalText], the
/// project's catalogue, rather than as the action's generic error text. A
/// not-authenticated answer shows nothing and signs out: the session is over,
/// and the sign-in screen is the message. Both still travel through
/// `dw.handleError`, so an app's error policy sees everything and sorts them
/// out by type.
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
        // A result that is not a success is the exception it stands for.
        if (value is DwCallResult && value is! DwCallOk) value.valueOrThrow;

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
        // A refusal speaks for itself: its code and parameters name this
        // call and this user, and the catalogue renders them — so it wins
        // over the action's [onErrorNotification], which was written once,
        // for every way the action could fail.
        switch (error) {
          case DwRefusalException(:final refusal)
              when refusal.isIncompatibility &&
                  config.updateRequiredScreen != null:
            // The update-required page is already the message; a toast over
            // it would say the same thing worse.
            break;
          case DwRefusalException(:final refusal):
            final text = config.refusalText?.call(refusal);
            if (text != null) {
              notify.error(text);
            } else if (onErrorNotification != null) {
              notify.error(onErrorNotification);
            }
          case DwNotAuthenticatedException():
            // Usually already over: the client drops the session on the
            // answer itself. This covers the exception thrown by app code.
            if (this case final DwFlutterCore core) {
              try {
                await core.signOut();
              } catch (signOutError, signOutStackTrace) {
                handleError(signOutError, signOutStackTrace);
              }
            }
          default:
            if (onErrorNotification != null) notify.error(onErrorNotification);
        }
        onError?.call(error, stackTrace);
        handleError(
          error,
          stackTrace,
          source: DwErrorSource.uiAction,
          // Actions rarely get explicit labels — the notification texts make
          // a meaningful fallback name in error reports.
          actionLabel: label ?? onErrorNotification ?? onSuccessNotification,
          failedCall: switch (error) {
            DwFailedException(:final call) => call,
            _ => null,
          },
        );
        return null;
      }
    });
  }
}
