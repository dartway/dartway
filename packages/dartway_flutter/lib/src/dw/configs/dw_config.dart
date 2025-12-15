import 'package:flutter/material.dart';

import 'dw_telegram_web_app_config.dart';

class DwConfig {
  const DwConfig({
    this.globalErrorHandler = debugInfoErrorHandler,
    this.defaultModelGetter,
    this.useSharedPreferences = true,
    this.telegramWebAppConfig,
    // this.flutterDotEnvFile,
  });
  final bool useSharedPreferences;
  final DwTelegramWebAppConfig? telegramWebAppConfig;
  // final String? flutterDotEnvFile;

  final void Function(Object error, StackTrace stackTrace)? globalErrorHandler;
  final T Function<T>()? defaultModelGetter;

  static debugInfoErrorHandler(Object error, StackTrace stackTrace) =>
      debugPrint('$error\n$stackTrace');
}
