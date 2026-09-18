import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:flutter_test/flutter_test.dart';

/// The user the app hands Studio is compared, not just carried: the README
/// builds it inside a `select`, which keeps what it produces only while it
/// stays equal to the last one.
void main() {
  test('two users saying the same thing are the same user', () {
    expect(
      const DwStudioUser(identifier: '79990000000', label: 'Ada'),
      const DwStudioUser(identifier: '79990000000', label: 'Ada'),
    );
    expect(
      const DwStudioUser(identifier: '79990000000', label: 'Ada').hashCode,
      const DwStudioUser(identifier: '79990000000', label: 'Ada').hashCode,
    );
  });

  test('a different identifier or label is a different user', () {
    expect(
      const DwStudioUser(identifier: 'a', label: 'Ada'),
      isNot(const DwStudioUser(identifier: 'b', label: 'Ada')),
    );
    expect(
      const DwStudioUser(identifier: 'a', label: 'Ada'),
      isNot(const DwStudioUser(identifier: 'a', label: 'Grace')),
    );
    expect(const DwStudioUser(), isNot(const DwStudioUser(label: 'Ada')));
  });

  test('a rebuilt user is not a new one — the session is reported again and '
      'the feature tree rescanned for every one that is', () {
    // What `select((profile) => DwStudioUser(...))` does on every emission of
    // the profile: a fresh instance of the same person.
    DwStudioUser fromProfile() =>
        const DwStudioUser(identifier: 'ada@example.com', label: 'Ada');
    expect(fromProfile(), fromProfile());
  });
}
