import 'dart:async';
import 'dart:io';

import 'package:dartway_serverpod_core_flutter/app/socket/service/streaming_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isStreamingConnectionError', () {
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
