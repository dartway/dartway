import 'dart:convert';

import 'package:http/http.dart' as http;

import '../alerts/dw_alert_formatter.dart';
import '../alerts/dw_alerts.dart';

class DwTelegramService {
  static const _telegramLimit = 4096;

  /// How long one send is allowed to take before it is given up on.
  ///
  /// Alerts are a side channel — nothing waits on them — which is exactly why
  /// a missing deadline is dangerous rather than harmless: where the route to
  /// `api.telegram.org` is blocked by a firewall that drops packets instead of
  /// refusing them, the connection does not fail, it hangs. Every alert then
  /// parks a socket for the platform default (minutes), and a server that
  /// reports errors in bursts runs out of them.
  static const sendTimeout = Duration(seconds: 10);

  /// Sends a message to Telegram (MarkdownV2). With [escapeMessage] the whole
  /// text is escaped and truncated (plain-text callers); pass `false` for
  /// messages that are already valid MarkdownV2 (e.g. built by
  /// [DwAlertFormatter]) — they only get the safety truncation.
  ///
  /// [client] is the transport to send through. Omitted, a plain client is
  /// built for the call and closed after it — direct access, which is what
  /// every deployment that can reach Telegram wants. A deployment that cannot
  /// passes one that goes through a proxy; on the server
  /// `DwProxyHttpClient.fromEnv` builds it. The client is never closed here
  /// when the caller supplied it: it is theirs, and it is reused across alerts.
  static Future<void> sendMessage({
    required String message,
    required String chatId,
    required String token,
    String? messageThreadId,
    bool escapeMessage = true,
    Function(String message)? reportErrorFunction,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final safeMessage = escapeMessage
          ? _prepareMessage(message)
          : _truncate(message);

      final url = Uri.parse("https://api.telegram.org/bot$token/sendMessage");

      final body = {
        "chat_id": chatId,
        "text": safeMessage,
        "parse_mode": "MarkdownV2",
        if (messageThreadId != null) "message_thread_id": messageThreadId,
      };

      final res = await httpClient
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(sendTimeout);

      if (res.statusCode != 200) {
        (reportErrorFunction ?? DwAlerts.instance.sendMessage)(
          "⚠️ DwTelegramService: Error response ${res.statusCode}: ${res.body}",
        );
      }
    } catch (e) {
      (reportErrorFunction ?? DwAlerts.instance.sendError)(
        "⚠️ DwTelegramService: Exception while sending message: $e",
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Escapes MarkdownV2 specials and truncates to the safe length.
  static String _prepareMessage(String message) =>
      _truncate(DwAlertFormatter.escapeMarkdownV2(message));

  /// Safety net: fits [message] into the Telegram limit without leaving a
  /// dangling escape backslash at the cut point.
  static String _truncate(String message) {
    if (message.length <= _telegramLimit) return message;
    var cut = message.substring(0, _telegramLimit - 20);
    if (cut.endsWith('\\')) cut = cut.substring(0, cut.length - 1);
    return '$cut\n…';
  }
}
