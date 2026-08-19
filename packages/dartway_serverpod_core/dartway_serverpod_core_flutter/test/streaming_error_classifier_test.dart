import 'dart:async';
import 'dart:io';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/socket/service/streaming_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // This predicate is not only about which errors stay quiet. It is the single
  // condition under which `dw.repo` puts a failed write into local storage
  // instead of raising it, so every answer below decides where data goes.
  // Widening it moves errors into the outbox; narrowing it drops writes on the
  // floor that should have been kept.
  group('isStreamingConnectionError', () {
    test('swallows every failure the method-stream client raises', () {
      final connectionErrors = <Object>[
        const WebSocketClosedException(),
        const WebSocketConnectException('offline'),
        const WebSocketListenException('dropped'),
        const ConnectionClosedException(),
        ConnectionAttemptTimedOutException(),
        const MethodStreamIdleTimeoutException(),
      ];

      for (final error in connectionErrors) {
        expect(
          isStreamingConnectionError(error),
          isTrue,
          reason: 'should swallow: $error',
        );
      }
    });

    test('does not swallow a subscription the server closed', () {
      // The one error on this path that is an answer rather than noise: it
      // ends a session or names a broken channel declaration, and filtering it
      // out here would hide both.
      expect(
        isStreamingConnectionError(
          DwChannelClosed(
            channel: 'userUpdates1',
            reason: DwChannelClosedReason.authenticationRevoked,
          ),
        ),
        isFalse,
      );
    });

    test('recognizes each connection-level pattern as noise', () {
      final connectionErrors = <Object>[
        Exception('Failed to connect WebSocket'),
        Exception('WebSocketChannelException: Failed to connect WebSocket'),
        Exception('WebSocketException: connection was not upgraded'),
        const SocketException('Connection refused'),
        TimeoutException('no response', const Duration(seconds: 5)),
        Exception('Failed to fetch'),
        Exception('Server returned statusCode = -1'),
      ];

      for (final error in connectionErrors) {
        expect(
          isStreamingConnectionError(error),
          isTrue,
          reason: 'should swallow: $error',
        );
      }
    });

    test('refuses the errors a replay must never retry', () {
      // The ones that would be catastrophic to queue: the server already gave
      // its answer, and replaying it later asks the same refused question
      // again — sometimes as a different user.
      final answeredErrors = <Object>[
        Exception('Not authenticated'),
        Exception('Forbidden'),
        Exception('Validation failed: title must not be empty'),
        StateError('Repository response reported an unsuccessful read.'),
      ];

      for (final error in answeredErrors) {
        expect(
          isStreamingConnectionError(error),
          isFalse,
          reason: 'must never reach the outbox: $error',
        );
      }
    });

    test('treats arbitrary domain errors as real (must propagate)', () {
      final domainErrors = <Object>[
        StateError('invalid state transition'),
        ArgumentError('bad argument'),
        Exception('User profile not found'),
        FormatException('unexpected token'),
      ];

      for (final error in domainErrors) {
        expect(
          isStreamingConnectionError(error),
          isFalse,
          reason: 'should propagate: $error',
        );
      }
    });
  });
}
