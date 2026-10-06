import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

void main() {
  test(
    'delivery preference survives protocol decoding and distinguishes commands',
    () {
      const defaultRequest = DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000001',
      );
      const smsRequest = DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000001',
        deliveryHint: 'sms',
      );
      expect(defaultRequest.toJson(), isNot(contains('deliveryHint')));
      expect(DwRequestCode.fromJson(defaultRequest.toJson()), defaultRequest);
      expect(
        DwWireProtocol.core.decodeNamed('DwRequestCode', smsRequest.toJson()),
        smsRequest,
      );
      expect(smsRequest, isNot(defaultRequest));
      expect({defaultRequest, smsRequest}, hasLength(2));
      expect(
        DwRequestCode.fromJson({
          ...defaultRequest.toJson(),
          'deliveryHint': null,
        }),
        defaultRequest,
      );
    },
  );
}
