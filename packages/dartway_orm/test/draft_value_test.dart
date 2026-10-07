import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/app_setting.dart';
import 'fixtures/club_service.dart';

/// A draft is a value like the row it becomes: two drafts with the same
/// columns are one draft, whatever their identity.
void main() {
  NewClubServiceRow yoga({List<String> tags = const []}) => NewClubServiceRow(
    title: 'Yoga',
    kind: ClubServiceKind.group,
    duration: const Duration(hours: 1),
    availableOn: DwCalendarDay(2026, 9, 1),
    tags: tags,
    createdAt: DateTime.utc(2026, 9, 1),
  );

  test('drafts with equal columns are equal and hash alike', () {
    // Lists compare by their elements, not by identity.
    final a = yoga(tags: ['a', 'b']);
    final b = yoga(tags: ['a', 'b']);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(yoga(tags: ['b', 'a'])));
    expect(a, isNot(a.copyWith(title: 'Pilates')));
  });

  test('a set of drafts keeps one of each value', () {
    final drafts = {
      yoga(),
      yoga(),
      yoga(tags: ['x']),
      yoga().copyWith(price: const DwFieldPatch.set(10)),
    };
    expect(drafts, hasLength(3));
  });

  test('toString names the draft and every column', () {
    final setting = NewAppSettingRow(
      key: 'limits',
      value: 'v',
      updatedAt: DateTime.utc(2026),
    );
    expect(
      setting.toString(),
      allOf(
        startsWith('NewAppSettingRow('),
        contains('key: limits'),
        contains('value: v'),
        isNot(contains('id:')),
      ),
    );
  });

  test('a draft is never equal to the row it becomes', () {
    final draft = yoga();
    expect(draft.withId(1), isNot(draft));
    expect(draft.withId(1), draft.withId(1));
  });
}
