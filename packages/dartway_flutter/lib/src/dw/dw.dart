import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_flutter/src/notifications/service/dw_notifications_controller.dart';
import 'package:dartway_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telegram_app/telegram_app.dart';

part 'parts/dw_navigation.dart';
part 'parts/dw_notifications.dart';
part 'parts/dw_services.dart';

class DwFlutter {
  DwFlutter({required DwConfig config}) : _config = config {
    setDwInstance(this);
  }

  final DwConfig _config;

  final notify = _DwNotifications._();
  final services = _DwServices._();
  final navigation = _DwNavigation._();

  Future<void> init() async {
    await services._init(config: _config);
  }

  void handleError(Object error, StackTrace stackTrace) =>
      _config.globalErrorHandler?.call(error, stackTrace);

  bool get isDefaultModelsGetterSetUp => _config.defaultModelGetter != null;

  T getDefaultModel<T>() {
    final getter = _config.defaultModelGetter;

    if (getter == null) {
      throw StateError(
        'DwFlutter.defaultModelGetter is not set. '
        'Please provide it in DwConfig when initializing DwApp',
      );
    }

    return getter<T>();
  }

  DwUiAction<T> action<T>(
    FutureOr<T> Function(BuildContext context) action, {
    FutureOr<void> Function(BuildContext mountedContext, T actionResult)?
    followUpIfMountedAction,
    String? onSuccessNotification,

    String? onErrorNotification,
    FutureOr<DwUiNotification> Function(T actionResult)?
    customNotificationBuilder,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return DwUiAction<T>.create(
      action,
      followUpIfMountedAction: followUpIfMountedAction,
      onSuccessNotification: onSuccessNotification,
      customNotificationBuilder: customNotificationBuilder,
      onErrorNotification: onErrorNotification,
      onError: onError,
    );
  }
}
