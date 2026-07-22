import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:test/test.dart';

void main() {
  test('public safe exception code never exposes the exception message', () {
    const secret = 'provider-token-should-not-leak';

    final code = dwPushSafeExceptionCode(StateError(secret));

    expect(code, 'exception_StateError');
    expect(code, isNot(contains(secret)));
  });
}
