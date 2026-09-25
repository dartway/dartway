import 'dart:async';
import 'dart:convert';

import 'package:dartway_client/dartway_client.dart';

/// Waits until [condition] holds, checking it every [interval]; throws a
/// [TimeoutException] naming [reason] when [timeout] passes first.
///
/// For what a test cannot await directly: an update that arrives on the
/// socket, a job that runs after the command committed, a watch going live.
/// Every project's harness used to carry its own copy.
Future<void> dwWaitUntil(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 20),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'not met within $timeout${reason == null ? '' : ': $reason'}',
        timeout,
      );
    }
    await Future<void>.delayed(interval);
  }
}

/// Real HTTP, counting the calls per wire name and keeping the last answer
/// to each: what lets a test say "the update arrived and nothing asked for
/// it again".
final class DwCountingTransport implements DwHttpTransport {
  DwCountingTransport([DwHttpTransport? inner])
    : _inner = inner ?? DwHttpClientTransport();

  final DwHttpTransport _inner;
  final Map<String, int> _posts = {};
  final Map<String, DwHttpReply> _replies = {};

  /// How many calls named [wireName] were posted.
  int posts(String wireName) => _posts[wireName] ?? 0;

  /// The body of the last answer to [wireName], decoded.
  Map<String, Object?> lastReply(String wireName) =>
      jsonDecode(_replies[wireName]!.body) as Map<String, Object?>;

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    final wireName = post.url.pathSegments.last;
    _posts.update(wireName, (n) => n + 1, ifAbsent: () => 1);
    return _replies[wireName] = await _inner.post(post);
  }

  @override
  void close() => _inner.close();
}

/// The real live socket, with every frame the server sent recorded, decoded.
final class DwRecordingConnector implements DwLiveConnector {
  DwRecordingConnector([DwLiveConnector? inner])
    : _inner = inner ?? const DwWebSocketConnector();

  final DwLiveConnector _inner;

  /// Every frame received, in order, on every connection this connector made.
  final List<Map<String, Object?>> received = [];

  /// The updates received on [channel].
  List<Map<String, Object?>> updatesOn(DwLiveChannel channel) =>
      _framesOf('upd', channel);

  /// The refusals of subscriptions to [channel].
  List<Map<String, Object?>> refusalsOf(DwLiveChannel channel) =>
      _framesOf('subno', channel);

  /// The server ending subscriptions to [channel].
  List<Map<String, Object?>> closuresOf(DwLiveChannel channel) =>
      _framesOf('closed', channel);

  List<Map<String, Object?>> _framesOf(String kind, DwLiveChannel channel) => [
    for (final frame in received)
      if (frame['k'] == kind && frame['ch'] == channel.wireName) frame,
  ];

  @override
  Future<DwLiveConnection> connect(Uri url) async =>
      _RecordingConnection(await _inner.connect(url), received);
}

final class _RecordingConnection implements DwLiveConnection {
  _RecordingConnection(this._inner, this._received);

  final DwLiveConnection _inner;
  final List<Map<String, Object?>> _received;

  @override
  late final Stream<String> messages = _inner.messages.map((frame) {
    _received.add(jsonDecode(frame) as Map<String, Object?>);
    return frame;
  });

  @override
  void send(String frame) => _inner.send(frame);

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> close([int? code, String? reason]) => _inner.close(code, reason);
}
