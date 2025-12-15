import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';

class DwAlerts {
  final DwTelegramAlertsConfig? _telegramConfig;
  final Function(String message)? _logFunction;
  final bool _logMessages;
  final bool _logErrors;

  static DwAlerts? _instance;

  static DwAlerts get instance {
    if (_instance == null) {
      throw Exception('DwAlerts not initialized. Call DwAlerts.init() first.');
    }
    return _instance!;
  }

  static DwAlerts init({
    DwTelegramAlertsConfig? telegramConfig,
    Function(String message) logFunction = print,
    bool logMessages = false,
    bool logErrors = true,
  }) {
    _instance = DwAlerts._(
      telegramConfig: telegramConfig,
      logFunction: logFunction,
      logMessages: logMessages,
      logErrors: logErrors,
    );

    return _instance!;
  }

  DwAlerts._({
    DwTelegramAlertsConfig? telegramConfig,
    Function(String message)? logFunction,
    required bool logMessages,
    required bool logErrors,
  }) : _telegramConfig = telegramConfig,
       _logFunction = logFunction,
       _logMessages = logMessages,
       _logErrors = logErrors;

  // DwAlerts.debug({
  //   Function(String message)? logFunction = print,
  //   bool logAlertMessages = true,
  //   bool logErrors = true,
  // }) : _telegramConfig = null,
  //      _logFunction = logFunction,
  //      _logAlertMessages = logAlertMessages,
  //      _logErrors = logErrors;

  // DwAlerts.none()
  //   : _telegramConfig = null,
  //     _logFunction = null,
  //     _logAlertMessages = false,
  //     _logErrors = false;

  void sendMessage(String message) {
    _sendAlert(message, logMessage: _logMessages);
  }

  void sendError(String message) {
    _sendAlert(message, logMessage: _logErrors);
  }

  void reportError(
    String errorMessage, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    // Формируем тело сообщения с ограничением длины
    final stack = stackTrace?.toString().trim() ?? '';

    final fullMessage =
        '❌ *Error:*\n${errorMessage.toString()}\n\n'
        '📌 *Exception:*\n${exception?.toString()}\n\n'
        '📜 *StackTrace:*\n'
        '$stack';

    _sendAlert(fullMessage, logMessage: _logErrors);
  }

  _sendAlert(
    String message, {
    required bool logMessage,
    bool suppressErrors = false,
  }) {
    if (_telegramConfig != null) {
      DwTelegramService.sendMessage(
        message: message,
        chatId: _telegramConfig.alertsChatId,
        messageThreadId: _telegramConfig.alertsMessageThreadId,
        token: _telegramConfig.alertsToken,
        reportErrorFunction: suppressErrors ? (_) {} : _sendAlertingError,
      );
    }

    if (logMessage) {
      try {
        _logFunction?.call(message);
      } catch (e) {
        if (!suppressErrors) {
          _sendAlertingError("Error logging alert message: $e");
        }
      }
    }
  }

  _sendAlertingError(String message) {
    _sendAlert(message, logMessage: _logErrors, suppressErrors: true);

    // try {
    //   if (_logErrors) {
    //     _logFunction?.call(message);
    //   }
    // } catch (e) {
    //   _logError("Error logging error message: $e", fromAlerting: fromAlerting);
    // }
  }
}
