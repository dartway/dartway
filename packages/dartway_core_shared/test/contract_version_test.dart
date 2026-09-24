import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  group('DwContractVersion (#296)', () {
    test('the breaking line is the major version, or the minor below 1.0', () {
      expect(DwContractVersion('3.4.1').line, '3');
      expect(DwContractVersion('0.7.2').line, '0.7');
      expect(DwContractVersion('0.7.2-dev.1+5').line, '0.7');
    });

    test('an older line cannot speak a newer one; the same line can', () {
      bool older(String a, String b) =>
          DwContractVersion(a).isOlderLineThan(DwContractVersion(b));
      expect(older('0.7.9', '0.8.0'), isTrue);
      expect(older('0.8.0', '0.8.5'), isFalse, reason: 'additive');
      expect(older('0.8.5', '0.8.0'), isFalse);
      expect(older('1.9.0', '2.0.0'), isTrue);
      expect(older('2.0.0', '2.7.0'), isFalse, reason: 'additive above 1.0');
      expect(older('0.9.0', '1.0.0'), isTrue);
      expect(older('0.9.0', '0.8.0'), isFalse, reason: 'a newer app');
    });

    test('a header that is not a version is a format error', () {
      expect(() => DwContractVersion.parse('seven'), throwsFormatException);
    });

    test("a protocol composed over the app's keeps its contract version", () {
      final app = DwWireProtocol(const [], contractVersion: '0.3.1');
      final module = DwWireProtocol(const [], include: app);
      expect(module.contractVersion, DwContractVersion('0.3.1'));
      expect(DwWireProtocol.core.contractVersion, isNull);
    });
  });
}
