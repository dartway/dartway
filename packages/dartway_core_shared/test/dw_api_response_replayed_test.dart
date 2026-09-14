import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  final protocol = DwWireProtocol(const []);

  Object? wire(Object? json) => jsonDecode(jsonEncode(json));

  test('a replayed ok travels as a flag and nothing else', () {
    const replay = DwApiResponse.ok(7, replayed: true);
    final json = wire(replay.toJson())! as Map<String, Object?>;
    expect(json['replayed'], isTrue);
    final back = DwApiResponse.fromJson(json, protocol) as DwApiOk;
    expect(back.replayed, isTrue);
    expect(back.result, 7);
  });

  test('a first execution carries no flag', () {
    final json =
        wire(const DwApiResponse.ok(7).toJson())! as Map<String, Object?>;
    expect(json.containsKey('replayed'), isFalse);
    expect(
      (DwApiResponse.fromJson(json, protocol) as DwApiOk).replayed,
      isFalse,
    );
  });

  test('a malformed flag is refused', () {
    expect(
      () =>
          DwApiResponse.fromJson({'status': 'ok', 'replayed': false}, protocol),
      throwsFormatException,
    );
  });
}
