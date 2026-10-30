import 'package:dartway_core_shared/src/diagnostics/dw_error_signature.dart';
import 'package:test/test.dart';

void main() {
  test('selects application frames from VM, Flutter and dart2js stacks', () {
    expect(
      dwFirstAppFrame('#0 dart:async/x\n#1 package:app/feature.dart:42'),
      'package:app/feature.dart:42',
    );
    expect(
      dwFirstAppFrame('#0 package:flutter/x\n#1 package:my_app/main.dart 2:3'),
      'package:my_app/main.dart 2:3',
    );
    expect(
      dwFirstAppFrame(
        'dart-sdk/lib/_internal/js_dev_runtime/x 1:1\nmain.dart.js 4:8',
      ),
      'main.dart.js 4:8',
    );
  });

  test('caps an untrusted application frame for indexed signatures', () {
    final frame = 'package:app/${List.filled(16 << 10, 'x').join()}';
    expect(dwFirstAppFrame('#0 $frame').length, lessThanOrEqualTo(512));
  });
}
