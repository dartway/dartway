import 'dart:convert';

import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
import 'package:http/http.dart' as http;

class DwTelegramService {
  static const _telegramLimit = 4096;

  /// Отправка сообщения в Telegram с автоматическим экранированием и обрезкой.
  static Future<void> sendMessage({
    required String message,
    required String chatId,
    required String token,
    String? messageThreadId,
    Function(String message)? reportErrorFunction,
  }) async {
    try {
      // 🧩 Подготовка текста
      final safeMessage = _prepareMessage(message);

      final url = Uri.parse("https://api.telegram.org/bot$token/sendMessage");

      final body = {
        "chat_id": chatId,
        "text": safeMessage,
        "parse_mode": "MarkdownV2",
        if (messageThreadId != null) "message_thread_id": messageThreadId,
      };

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        (reportErrorFunction ?? DwAlerts.instance.sendMessage)(
          "⚠️ DwTelegramService: Error response ${res.statusCode}: ${res.body}",
        );
      }
    } catch (e) {
      (reportErrorFunction ?? DwAlerts.instance.sendError)(
        "⚠️ DwTelegramService: Exception while sending message: $e",
      );
    }
  }

  /// Экранирует спецсимволы MarkdownV2 и обрезает до безопасной длины.
  static String _prepareMessage(String message) {
    final escaped = message.replaceAllMapped(
      RegExp(r'([_*\[\]()~`>#+\-=|{}.!])'),
      (m) => '\\${m.group(1)}',
    );

    if (escaped.length <= _telegramLimit) return escaped;
    return '${escaped.substring(0, _telegramLimit - 20)}\\n…';
  }
}
