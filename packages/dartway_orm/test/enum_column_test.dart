import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

enum PlanStatus { draft, active }

enum FeedKind with DwOpenEnum { created, renamed, unknown }

void main() {
  group('a strict enum column', () {
    const column = DwEnumType(PlanStatus.values);

    test('reads its names and fails on one this build does not know', () {
      expect(column.decode('active'), PlanStatus.active);
      expect(
        () => column.decode('archived'),
        throwsA(isA<DwDecodeException>()),
      );
    });
  });

  group('an open enum column', () {
    const column = DwEnumType(FeedKind.values);
    const list = DwEnumListType(FeedKind.values);

    test('reads a name this build does not know as unknown', () {
      expect(column.decode('renamed'), FeedKind.renamed);
      expect(column.decode('decompositionCancelled'), FeedKind.unknown);
      expect(list.decode(['created', 'prioritized']), [
        FeedKind.created,
        FeedKind.unknown,
      ]);
    });

    test('never writes unknown, so the name it stands for is not replaced', () {
      expect(column.encode(FeedKind.created), 'created');
      expect(() => column.encode(FeedKind.unknown), throwsStateError);
      expect(() => list.encode([FeedKind.unknown]), throwsStateError);
    });
  });
}
