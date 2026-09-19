import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

enum PlanStatus { draft, active }

enum FeedKind with DwOpenEnum { created, renamed, unknown }

enum BrokenOpen with DwOpenEnum { one, two }

void main() {
  test(
    'a strict enum reads its names and names an unknown one as newer data',
    () {
      expect(
        DwJsonCodec.decodeEnum('active', PlanStatus.values),
        PlanStatus.active,
      );
      expect(
        () => DwJsonCodec.decodeEnum('archived', PlanStatus.values),
        throwsA(
          isA<DwUnknownEnumValue>()
              .having((e) => e.value, 'value', 'archived')
              .having((e) => e.enumType, 'enumType', PlanStatus),
        ),
      );
    },
  );

  test('an open enum reads an unknown name as unknown', () {
    expect(
      DwJsonCodec.decodeEnum('renamed', FeedKind.values),
      FeedKind.renamed,
    );
    expect(
      DwJsonCodec.decodeEnum('prioritized', FeedKind.values),
      FeedKind.unknown,
    );
    expect(FeedKind.unknown.isUnknown, isTrue);
  });

  test('unknown is never written, and says so by its own type', () {
    expect(DwJsonCodec.encodeEnum(FeedKind.renamed), 'renamed');
    expect(DwJsonCodec.encodeEnum(PlanStatus.draft), 'draft');
    expect(
      () => DwJsonCodec.encodeEnum(FeedKind.unknown),
      throwsA(
        isA<DwUnknownEnumWrite>()
            .having((e) => e.enumType, 'enumType', FeedKind)
            .having((e) => '$e', 'toString', contains('update the app')),
      ),
    );
  });

  test('an open enum without unknown is named when it is first read', () {
    expect(
      () => DwJsonCodec.decodeEnum('three', BrokenOpen.values),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('unknown'),
        ),
      ),
    );
  });
}
