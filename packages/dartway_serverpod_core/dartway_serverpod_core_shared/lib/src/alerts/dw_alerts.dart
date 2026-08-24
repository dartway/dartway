import 'package:http/http.dart' as http;

import '../services/dw_telegram_service.dart';
import 'configs/dw_telegram_alerts_config.dart';
import 'dw_alert_context.dart';
import 'dw_alert_formatter.dart';

class DwAlerts {
  final DwTelegramAlertsConfig? _telegramConfig;
  final http.Client? _httpClient;
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

  /// Builds the process-wide sink.
  ///
  /// [httpClient] is the transport alerts are sent through. Left null — the
  /// usual case — each send builds and closes a plain client of its own, which
  /// reaches Telegram directly. Where outbound access to `api.telegram.org` is
  /// blocked, the server passes a proxying client built by
  /// `DwProxyHttpClient.fromEnv`; it is kept for the lifetime of the process,
  /// so pass one that is safe to reuse.
  static DwAlerts init({
    DwTelegramAlertsConfig? telegramConfig,
    http.Client? httpClient,
    Function(String message) logFunction = print,
    bool logMessages = false,
    bool logErrors = true,
  }) {
    _instance = DwAlerts._(
      telegramConfig: telegramConfig,
      httpClient: httpClient,
      logFunction: logFunction,
      logMessages: logMessages,
      logErrors: logErrors,
    );

    return _instance!;
  }

  DwAlerts._({
    DwTelegramAlertsConfig? telegramConfig,
    http.Client? httpClient,
    Function(String message)? logFunction,
    required bool logMessages,
    required bool logErrors,
  }) : _telegramConfig = telegramConfig,
       _httpClient = httpClient,
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
        client: _httpClient,
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
