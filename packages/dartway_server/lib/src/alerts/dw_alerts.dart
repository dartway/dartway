import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'dw_logger.dart';

/// A failure: something the operator must hear about. Refusals are never
/// incidents — they are answers.
final class DwIncident {
  DwIncident({
    required this.id,
    required this.where,
    required this.error,
    required this.stackTrace,
    this.accountId,
    DateTime? at,
  }) : at = at ?? DateTime.now().toUtc();

  /// What the client received as `DwFailed.incidentId`.
  final String id;

  /// Where it happened, without payload: `command BookSession`, `job reminder`.
  final String where;
  final Object error;
  final StackTrace stackTrace;
  final int? accountId;
  final DateTime at;

  /// Identical failures share a signature: the place, the error type and the
  /// first frame of the stack. The ceiling counts by it.
  String get signature =>
      '$where|${error.runtimeType}|${dwFirstFrame(stackTrace)}';

  /// A random id short enough to read aloud, long enough never to collide in
  /// an operator's search.
  static String newId() {
    final random = Random.secure();
    const alphabet = '0123456789abcdefghjkmnpqrstvwxyz';
    return List.generate(12, (_) => alphabet[random.nextInt(32)]).join();
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
abstract interface class DwAlerts {
  /// Delivers an incident. [suppressedNote] is set on the last alert a
  /// signature sends before the ceiling mutes it.
  Future<void> send(DwIncident incident, {String? suppressedNote});
}

/// The default sink: the log, at error level.
final class DwLogAlerts implements DwAlerts {
  const DwLogAlerts(this.logger);

  final DwLogger logger;

  @override
  Future<void> send(DwIncident incident, {String? suppressedNote}) async {
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
/// (truncated) — never payloads. A delivery failure is logged, not thrown: an
/// alert channel that is down must not turn into a second incident loop.
final class DwTelegramAlerts implements DwAlerts {
  DwTelegramAlerts({
    required this.botToken,
    required this.chatId,
    required this.logger,
    this.title = 'DartWay',
    http.Client? client,
    Uri? apiBase,
  }) : _client = client ?? http.Client(),
       _apiBase = apiBase ?? Uri.parse('https://api.telegram.org');

  final String botToken;
  final String chatId;
  final String title;
  final DwLogger logger;
  final http.Client _client;
  final Uri _apiBase;

  @override
  Future<void> send(DwIncident incident, {String? suppressedNote}) async {
    var errorText = '${incident.error}';
    if (errorText.length > 1500) errorText = '${errorText.substring(0, 1500)}…';
    final text = StringBuffer()
      ..writeln('$title: failure ${incident.id}')
      ..writeln(incident.where)
      ..writeln(errorText)
      ..writeln(dwFirstFrame(incident.stackTrace));
    if (suppressedNote != null) text.writeln(suppressedNote);
    try {
      final response = await _client
          .post(
            _apiBase.replace(path: '/bot$botToken/sendMessage'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'chat_id': chatId, 'text': text.toString()}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        // The URL holds the token: report the status only.
        logger.warning(
          'Telegram alert for incident ${incident.id} was not delivered: '
          'HTTP ${response.statusCode}',
        );
      }
    } catch (error) {
      logger.warning(
        'Telegram alert for incident ${incident.id} was not delivered: '
        '${error.runtimeType}',
      );
    }
  }
}

/// Logs every incident and forwards it to [sink] under a per-signature
/// ceiling: at most [maxPerWindow] alerts of one signature per [window]. A
/// failure repeating a thousand times is one problem, and a channel flooded
/// with it hides the next one.
final class DwAlertGate {
  DwAlertGate({
    required this.sink,
    required this.logger,
    this.maxPerWindow = 5,
    this.window = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DwAlerts sink;
  final DwLogger logger;
  final int maxPerWindow;
  final Duration window;
  final DateTime Function() _clock;
  final Map<String, _SignatureWindow> _windows = {};

  /// Records a failure and returns its incident id.
  String report({
    required String where,
    required Object error,
    required StackTrace stackTrace,
    int? accountId,
  }) {
    final incident = DwIncident(
      id: DwIncident.newId(),
      where: where,
      error: error,
      stackTrace: stackTrace,
      accountId: accountId,
    );
    logger.error(
      'incident ${incident.id} in $where',
      error: error,
      stackTrace: stackTrace,
    );
    final now = _clock();
    _windows.removeWhere((_, w) => now.difference(w.start) >= window);
    final state = _windows.putIfAbsent(
      incident.signature,
      () => _SignatureWindow(now),
    );
    state.count++;
    if (state.count <= maxPerWindow) {
      final note = state.count == maxPerWindow
          ? 'further alerts like this are muted until '
                '${state.start.add(window).toUtc().toIso8601String()}'
          : null;
      unawaited(
        sink.send(incident, suppressedNote: note).catchError((Object e) {
          logger.warning('alert sink failed for ${incident.id}', error: e);
        }),
      );
    }
    return incident.id;
  }
}

final class _SignatureWindow {
  _SignatureWindow(this.start);

  final DateTime start;
  int count = 0;
}
