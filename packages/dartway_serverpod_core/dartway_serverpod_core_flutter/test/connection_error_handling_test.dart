import 'dart:async';

import 'package:dartway_serverpod_core_flutter/src/utils/connection_error_handling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dwConnectionAwareErrorHandler', () {
    test('routes a connection-level error to onConnectionError only', () {
      Object? connection;
      Object? unexpected;

      final handler = dwConnectionAwareErrorHandler(
        onConnectionError: (e) => connection = e,
        onUnexpectedError: (e, _) => unexpected = e,
      );

      final error = TimeoutException('Future not completed');
      handler(error, StackTrace.empty);

      expect(connection, same(error));
      expect(unexpected, isNull);
    });

    test('routes a non-connection error to onUnexpectedError only', () {
      Object? connection;
      Object? unexpected;

      final handler = dwConnectionAwareErrorHandler(
        onConnectionError: (e) => connection = e,
        onUnexpectedError: (e, _) => unexpected = e,
      );

      final error = StateError('genuine bug');
      handler(error, StackTrace.empty);

      expect(unexpected, same(error));
      expect(connection, isNull);
    });

    test('connection error with no onConnectionError is silently swallowed', () {
      var unexpectedCalled = false;

      final handler = dwConnectionAwareErrorHandler(
        onUnexpectedError: (_, _) => unexpectedCalled = true,
      );

      // Must not throw and must not reach onUnexpectedError.
      handler(Exception('Failed to fetch'), StackTrace.empty);

      expect(unexpectedCalled, isFalse);
    });
  });
}
