import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

import 'dw_server_logger.dart';

/// A failure: something the operator must hear about. Refusals are never
/// incidents — they are answers.
final class DwServerIncident {
  DwServerIncident({
    required this.id,
    required this.where,
    required this.error,
    required this.stackTrace,
    this.accountId,
    this.repeatCount = 0,
    this.occurrences = 1,
    this.project,
    this.environment,
    this.version,
    String? signature,
    DateTime? at,
  }) : at = at ?? DateTime.now().toUtc(),
       _signature = signature;

  /// What the client received as the `incidentId` of a failed answer.
  final String id;

  /// Where it happened, without payload: `command BookSession`, `job reminder`.
  final String where;
  final Object error;
  final StackTrace stackTrace;
  final int? accountId;

  /// Repetitions represented by a coalesced follow-up delivery.
  final int repeatCount;
  final int occurrences;

  /// Whether this is the first delivery or its coalesced follow-up.
  String get kind => repeatCount == 0 ? 'incident' : 'repeat';
  final String? project;
  final String? environment;
  final String? version;
  final DateTime at;

  /// Identical failures share a signature: the place, the error type and the
  /// first frame of the stack. The ceiling counts by it.
  final String? _signature;
  String get signature =>
      _signature ?? '$where|${error.runtimeType}|${dwFirstFrame(stackTrace)}';

  static final Random _random = Random.secure();

  /// A random id short enough to read aloud, long enough never to collide in
  /// an operator's search.
  static String newId() {
    const alphabet = '0123456789abcdefghjkmnpqrstvwxyz';
    return List.generate(12, (_) => alphabet[_random.nextInt(32)]).join();
  }
}

/// The first stack frame outside the SDK's async machinery.
String dwFirstFrame(StackTrace stackTrace) {
  for (final line in const LineSplitter().convert(stackTrace.toString())) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.contains('dart:async') || trimmed.contains('<asynchronous')) {
      continue;
    }
    return trimmed.replaceFirst(RegExp(r'^#\d+\s+'), '');
  }
  return '';
}

/// Where failures go. The framework logs every incident itself; a sink is the
/// channel that reaches a person (Telegram, a pager).
abstract interface class DwAlertSink {
  /// Delivers an incident. [suppressedNote] is set on the last alert a
  /// signature sends before the ceiling mutes it.
  Future<void> send(DwServerIncident incident, {String? suppressedNote});
}

/// Posts the stable DartWay alert contract to an HTTP receiver.
final class DwHttpAlertSink implements DwAlertSink {
  DwHttpAlertSink({required this.url, required this.token});

  final Uri url;
  final String token;
  static const _timeout = Duration(seconds: 10);

  @override
  Future<void> send(DwServerIncident incident, {String? suppressedNote}) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(url).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode({
          'id': incident.id,
          'kind': incident.kind,
          'where': incident.where,
          'error': _truncate('${incident.error}', 4 * 1024),
          'stackTrace': _truncate('${incident.stackTrace}', 16 * 1024),
          'accountId': incident.accountId,
          'at': incident.at.toUtc().toIso8601String(),
          'signature': incident.signature,
          'repeatCount': incident.repeatCount,
          'project': incident.project,
          'environment': incident.environment,
          'version': incident.version,
        }),
      );
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'alert endpoint returned HTTP ${response.statusCode}',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  static String _truncate(String value, int byteLimit) {
    if (utf8.encode(value).length <= byteLimit) return value;
    final result = StringBuffer();
    var bytes = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (bytes + size > byteLimit) break;
      result.write(character);
      bytes += size;
    }
    return result.toString();
  }
}

/// The default sink: the log, at error level.
final class DwLogAlertSink implements DwAlertSink {
  const DwLogAlertSink(this.logger);

  final DwServerLogger logger;

  @override
  Future<void> send(DwServerIncident incident, {String? suppressedNote}) async {
    logger.error(
      'ALERT incident ${incident.id} in ${incident.where}'
      '${suppressedNote == null ? '' : ' ($suppressedNote)'}',
      error: incident.error,
      stackTrace: incident.stackTrace,
    );
  }
}

/// Sends incidents to a Telegram chat through a bot.
///
/// The message carries the incident id, where it happened and the error text
/// (truncated) — never payloads. Delivery failures throw so the durable
/// outbox can retry them.
///
/// Speaks `dart:io`'s `HttpClient` directly: one POST does not justify an HTTP
/// package dependency in every server.
final class DwTelegramAlertSink implements DwAlertSink {
  DwTelegramAlertSink({
    required this.botToken,
    required this.chatId,
    required this.logger,
    this.title = 'DartWay',
    Uri? apiBase,
    this.proxyUrl,
  }) : _apiBase = apiBase ?? Uri.parse('https://api.telegram.org');

  final String botToken;
  final String chatId;
  final String title;
  DwServerLogger logger;
  final Uri? proxyUrl;
  final Uri _apiBase;

  static const Duration _timeout = Duration(seconds: 10);

  @internal
  void useLogger(DwServerLogger value) => logger = value;

  @override
  Future<void> send(DwServerIncident incident, {String? suppressedNote}) async {
    var errorText = '${incident.error}';
    if (errorText.length > 1500) errorText = '${errorText.substring(0, 1500)}…';
    final text = StringBuffer()
      ..writeln('$title: failure ${incident.id}')
      ..writeln(incident.where)
      ..writeln(errorText)
      ..writeln(dwFirstFrame(incident.stackTrace));
    if (suppressedNote != null) text.writeln(suppressedNote);
    final client = HttpClient()..connectionTimeout = _timeout;
    if (proxyUrl case final proxy?) {
      client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
      if (proxy.userInfo.isNotEmpty) {
        final separator = proxy.userInfo.indexOf(':');
        final user = separator < 0
            ? proxy.userInfo
            : proxy.userInfo.substring(0, separator);
        final password = separator < 0
            ? ''
            : proxy.userInfo.substring(separator + 1);
        client.addProxyCredentials(
          proxy.host,
          proxy.port,
          '',
          HttpClientBasicCredentials(
            Uri.decodeComponent(user),
            Uri.decodeComponent(password),
          ),
        );
      }
    }
    int? status;
    try {
      final request = await client
          .postUrl(_apiBase.replace(path: '/bot$botToken/sendMessage'))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'chat_id': chatId, 'text': text.toString()}));
      final response = await request.close().timeout(_timeout);
      status = response.statusCode;
      final responseBody = await utf8.decodeStream(response).timeout(_timeout);
      if (response.statusCode != 200) {
        Duration? retryAfter;
        if (response.statusCode == HttpStatus.tooManyRequests) {
          try {
            final decoded = jsonDecode(responseBody);
            final parameters = decoded is Map ? decoded['parameters'] : null;
            final seconds = parameters is Map
                ? parameters['retry_after']
                : null;
            if (seconds is int && seconds >= 0) {
              retryAfter = Duration(seconds: seconds);
            }
          } on FormatException {
            // Telegram and its proxies can return a non-JSON rate-limit body.
          }
        }
        throw DwTelegramAlertException(
          'HttpException',
          response.statusCode,
          retryAfter: retryAfter,
        );
      }
    } catch (error) {
      // dart:io exceptions can include the request URI, whose path contains
      // the bot token. Only the type and status cross the sink boundary.
      final sanitized = error is DwTelegramAlertException
          ? error
          : DwTelegramAlertException(error.runtimeType.toString(), status);
      logger.warning(
        'Telegram alert for incident ${incident.id} was not delivered',
        error: sanitized,
      );
      throw sanitized;
    } finally {
      client.close(force: true);
    }
  }
}

/// A Telegram delivery failure that never carries the bot URL or token.
final class DwTelegramAlertException implements Exception {
  const DwTelegramAlertException(
    this.errorType,
    this.statusCode, {
    this.retryAfter,
  });

  final String errorType;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() =>
      'Telegram alert failed: $errorType'
      '${statusCode == null ? '' : ', HTTP $statusCode'}';
}

/// Logs every incident and forwards it to [sink] under two ceilings: at most
/// [maxPerWindow] alerts of one signature per [window] — a failure repeating a
/// thousand times is one problem, and a channel flooded with it hides the next
/// one — and at most [maxPerMinute] alerts of any signatures in a minute, so
/// many different failures at once cannot exhaust the channel's own limit
/// (Telegram's is 20 a minute per group) and lose the rest to its refusals.
/// An alert past that ceiling is only logged, and the next one that goes out
/// says how many were held back.
@internal
final class DwAlertGate {
  DwAlertGate({
    required this.sink,
    required this.logger,
    this.maxPerWindow = 5,
    this.window = const Duration(hours: 1),
    this.maxPerMinute = 10,
    DateTime Function()? clock,
    this.enqueue,
  }) : _clock = clock ?? DateTime.now;

  final DwAlertSink sink;
  final DwServerLogger logger;
  final int maxPerWindow;
  final Duration window;
  final int maxPerMinute;
  final DateTime Function() _clock;
  final Future<void> Function(DwServerIncident incident)? enqueue;
  final Map<String, _SignatureWindow> _windows = {};

  /// When the alerts of the last minute went out.
  final List<DateTime> _recent = [];

  /// Alerts held back by [maxPerMinute] since the last one that went out.
  int _heldBack = 0;

  /// Records a failure and returns its incident id.
  String report({
    required String where,
    required Object error,
    required StackTrace stackTrace,
    int? accountId,
    String? signature,
    int occurrences = 1,
  }) {
    final incident = DwServerIncident(
      id: DwServerIncident.newId(),
      where: where,
      error: error,
      stackTrace: stackTrace,
      accountId: accountId,
      signature: signature,
      occurrences: occurrences,
    );
    logger.error(
      'incident ${incident.id} in $where',
      error: error,
      stackTrace: stackTrace,
    );
    if (enqueue case final persist?) {
      unawaited(
        persist(incident).catchError((Object e) {
          logger.warning('alert outbox failed for ${incident.id}', error: e);
        }),
      );
      return incident.id;
    }
    final now = _clock();
    _windows.removeWhere((_, w) => now.difference(w.start) >= window);
    final state = _windows.putIfAbsent(
      incident.signature,
      () => _SignatureWindow(now),
    );
    state.count++;
    if (state.count > maxPerWindow) return incident.id;
    _recent.removeWhere(
      (sent) => now.difference(sent) >= const Duration(minutes: 1),
    );
    if (_recent.length >= maxPerMinute) {
      _heldBack++;
      return incident.id;
    }
    _recent.add(now);
    final notes = [
      if (state.count == maxPerWindow)
        'further alerts like this are muted until '
            '${state.start.add(window).toUtc().toIso8601String()}',
      if (_heldBack > 0)
        '$_heldBack more alert(s) were held back by the limit of '
            '$maxPerMinute a minute; they are in the log',
    ];
    _heldBack = 0;
    final note = notes.isEmpty ? null : notes.join('; ');
    unawaited(
      (enqueue?.call(incident) ?? sink.send(incident, suppressedNote: note))
          .catchError((Object e) {
            logger.warning('alert sink failed for ${incident.id}', error: e);
          }),
    );
    return incident.id;
  }
}

final class _SignatureWindow {
  _SignatureWindow(this.start);

  final DateTime start;
  int count = 0;
}
