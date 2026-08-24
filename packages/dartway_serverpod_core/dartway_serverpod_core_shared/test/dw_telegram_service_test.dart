import 'dart:async';
import 'dart:convert';

import 'package:dartway_serverpod_core_shared/src/services/dw_telegram_service.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// A client that answers from [handler] and remembers whether anyone closed it.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  final List<http.BaseRequest> requests = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return handler(request);
  }

  @override
  void close() => closed = true;
}

http.StreamedResponse _response(int statusCode, [String body = '{"ok":true}']) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);

void main() {
  group('DwTelegramService.sendMessage', () {
    test('sends through the injected client', () async {
      final client = _RecordingClient((_) async => _response(200));

      await DwTelegramService.sendMessage(
        message: 'Deploy finished',
        chatId: '-100500',
        token: 'bot-token',
        messageThreadId: '7',
        client: client,
        reportErrorFunction: (message) => fail('unexpected report: $message'),
      );

      expect(client.requests, hasLength(1));
      final request = client.requests.single as http.Request;
      expect(
        request.url.toString(),
        'https://api.telegram.org/botbot-token/sendMessage',
      );

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['chat_id'], '-100500');
      expect(body['message_thread_id'], '7');
      expect(body['text'], 'Deploy finished');
    });

    test('leaves the injected client open — the sink reuses it', () async {
      final client = _RecordingClient((_) async => _response(200));

      await DwTelegramService.sendMessage(
        message: 'hello',
        chatId: 'chat',
        token: 'token',
        client: client,
      );

      expect(client.closed, isFalse);
    });

    test('reports a refusal from Telegram instead of throwing', () async {
      final reports = <String>[];
      final client = _RecordingClient(
        (_) async => _response(400, '{"description":"chat not found"}'),
      );

      await DwTelegramService.sendMessage(
        message: 'hello',
        chatId: 'chat',
        token: 'token',
        client: client,
        reportErrorFunction: reports.add,
      );

      expect(reports, hasLength(1));
      expect(reports.single, contains('400'));
      expect(reports.single, contains('chat not found'));
    });

    test('a send that runs out of time is reported, not left hanging', () async {
      // The real deadline is `sendTimeout`; a test cannot wait it out, so the
      // transport raises what the deadline would have raised. What is under
      // test is the handling: reported through the alert sink, and the future
      // completes rather than never returning.
      final reports = <String>[];
      final client = _RecordingClient(
        (_) => Future.error(TimeoutException('no answer', DwTelegramService.sendTimeout)),
      );

      await DwTelegramService.sendMessage(
        message: 'hello',
        chatId: 'chat',
        token: 'token',
        client: client,
        reportErrorFunction: reports.add,
      );

      expect(reports, hasLength(1));
      expect(reports.single, contains('TimeoutException'));
    });

    test('the deadline is short enough to keep sockets from piling up', () {
      expect(DwTelegramService.sendTimeout, lessThanOrEqualTo(const Duration(seconds: 15)));
    });
  });
}
