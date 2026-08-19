import 'package:dartway_offline_shared/dartway_offline_shared.dart';
import 'package:test/test.dart';

void main() {
  test('revision is stable across model and JSON field ordering', () {
    final first = <String, Object?>{
      'className': 'LearningLesson',
      'data': <String, Object?>{'id': 2, 'title': 'Second'},
      'isDeleted': false,
    };
    final second = <String, Object?>{
      'isDeleted': false,
      'data': <String, Object?>{'title': 'First', 'id': 1},
      'className': 'LearningLesson',
    };

    final revision = DwOfflineRepositoryContentRevision.compute([
      first,
      second,
    ]);
    final reorderedRevision = DwOfflineRepositoryContentRevision.compute([
      second,
      first,
    ]);

    expect(reorderedRevision, revision);
    expect(revision, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('revision changes when signed repository content changes', () {
    Map<String, Object?> model(String title) => <String, Object?>{
      'className': 'LearningLesson',
      'data': <String, Object?>{'id': 1, 'title': title},
      'isDeleted': false,
    };

    expect(
      DwOfflineRepositoryContentRevision.compute([model('First')]),
      isNot(DwOfflineRepositoryContentRevision.compute([model('Changed')])),
    );
  });

  test('repository responses reconstruct the same unique model set', () {
    final first = <String, Object?>{
      'className': 'LearningLesson',
      'data': <String, Object?>{'id': 1, 'title': 'First'},
      'isDeleted': false,
    };
    final second = <String, Object?>{
      'className': 'LearningMaterial',
      'data': <String, Object?>{'id': 2, 'title': 'Workbook'},
      'isDeleted': false,
    };

    expect(
      DwOfflineRepositoryContentRevision.computeFromRepositoryResponses([
        <String, Object?>{'isOk': true, 'value': first},
        <String, Object?>{
          'isOk': true,
          'value': <Object?>[first, second],
        },
      ]),
      DwOfflineRepositoryContentRevision.compute([first, second]),
    );
  });

  test('conflicting duplicate models fail closed', () {
    Map<String, Object?> model(String title) => <String, Object?>{
      'className': 'LearningLesson',
      'data': <String, Object?>{'id': 1, 'title': title},
      'isDeleted': false,
    };

    expect(
      () => DwOfflineRepositoryContentRevision.computeFromRepositoryResponses([
        <String, Object?>{'isOk': true, 'value': model('First')},
        <String, Object?>{'isOk': true, 'value': model('Changed')},
      ]),
      throwsFormatException,
    );
  });
}
