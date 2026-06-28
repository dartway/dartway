import 'dart:async';

import 'package:dartway_serverpod_core_flutter/app/socket/service/streaming_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [throwingTimerBody] inside a child zone guarded exactly like
/// `DwSocketService.init` (swallow connection errors, forward the rest), nested
/// inside a parent zone that records anything that escapes. Returns the error
/// that reached the parent, or `null` if nothing did.
Future<Object?> _escapedFromChildZone(void Function() throwingTimerBody) {
  final completer = Completer<Object?>();
  Object? escaped;

  runZonedGuarded(
    () {
      runZonedGuarded(throwingTimerBody, (error, stack) {
        if (isStreamingConnectionError(error)) {
          return; // connection-level → swallowed in the child zone
        }
        Zone.current.handleUncaughtError(error, stack); // forward upward
      });

      // Settle after the thrown-from-timer error has been dispatched.
      Timer(const Duration(milliseconds: 30), () => completer.complete(escaped));
    },
    (error, stack) => escaped = error,
  );

  return completer.future;
}

void main() {
  test('connection error from a child-zone timer never reaches the parent', () async {
    final escaped = await _escapedFromChildZone(() {
      Timer(
        const Duration(milliseconds: 10),
        () => throw Exception('Failed to connect WebSocket'),
      );
    });

    expect(escaped, isNull);
  });

  test('a real error from a child-zone timer is forwarded to the parent', () async {
    final escaped = await _escapedFromChildZone(() {
      Timer(
        const Duration(milliseconds: 10),
        () => throw StateError('genuine bug'),
      );
    });

    expect(escaped, isA<StateError>());
  });
}
