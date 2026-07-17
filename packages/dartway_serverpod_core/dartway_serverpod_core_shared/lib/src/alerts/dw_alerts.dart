import '../services/dw_telegram_service.dart';
import 'configs/dw_telegram_alerts_config.dart';
import 'dw_alert_context.dart';
import 'dw_alert_formatter.dart';

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

  void sendMessage(String message) {
    _sendAlert(message, logMessage: _logMessages);
  }

  void sendError(String message) {
    _sendAlert(message, logMessage: _logErrors);
  }

  /// Reports an error as a formatted alert. [context] renders the app state
  /// (route, features, action, platform...) into the message — on web builds
  /// it is the informative part, the minified stack is not. The stack is
  /// trimmed to [stackTraceMaxLines] (null = full).
  void reportError(
    String errorMessage, {
    Object? exception,
    StackTrace? stackTrace,
    DwAlertContext? context,
    int? stackTraceMaxLines = DwAlertFormatter.defaultStackTraceMaxLines,
  }) {
    final fullMessage = DwAlertFormatter.formatErrorReport(
      errorMessage: errorMessage,
      exception: exception,
      stackTrace: stackTrace,
      context: context,
      stackTraceMaxLines: stackTraceMaxLines,
    );

    _sendAlert(fullMessage, logMessage: _logErrors, isPreformatted: true);
  }

  void _sendAlert(
    String message, {
    required bool logMessage,
    bool suppressErrors = false,
    bool isPreformatted = false,
  }) {
    if (_telegramConfig != null) {
      DwTelegramService.sendMessage(
        message: message,
        chatId: _telegramConfig.alertsChatId,
        messageThreadId: _telegramConfig.alertsMessageThreadId,
        token: _telegramConfig.alertsToken,
        // Preformatted messages are already valid MarkdownV2 (values escaped,
        // template markup alive) — escaping them again would kill the markup.
        escapeMessage: !isPreformatted,
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

  void _sendAlertingError(String message) {
    _sendAlert(message, logMessage: _logErrors, suppressErrors: true);
  }
}
