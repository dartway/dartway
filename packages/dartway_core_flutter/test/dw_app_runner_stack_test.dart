import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an error handler gets a StackTrace whatever the platform handed it', () {
    final real = StackTrace.current;
    expect(DwAppRunner.stackOf(real), same(real));
    expect(DwAppRunner.stackOf(null), StackTrace.empty);
    // On the web a stack can arrive as a raw JavaScript value; its text is
    // kept, and the handler does not throw instead of reporting the error.
    final foreign = DwAppRunner.stackOf(_JsLikeStack());
    expect(foreign, isA<StackTrace>());
    expect('$foreign', 'at main.dart.js:1:2');
  });
}

final class _JsLikeStack {
  @override
  String toString() => 'at main.dart.js:1:2';
}
