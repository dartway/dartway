import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

void main() {
  group('normalising', () {
    test('case and surrounding space do not make a second identity', () {
      expect(StarterHandle.normalise('  Ann_Lee '), 'ann_lee');
    });
  });

  group('validity', () {
    test('a usable handle has no reason against it', () {
      expect(StarterHandle.reasonInvalid('ann_lee'), isNull);
      expect(StarterHandle.isValid('ann_lee'), isTrue);
    });

    test('too short, too long, and the wrong alphabet each say which', () {
      expect(StarterHandle.reasonInvalid('an'), contains('at least'));
      expect(StarterHandle.reasonInvalid('a' * 31), contains('at most'));
      expect(StarterHandle.reasonInvalid('ann lee'), contains('underscores'));
    });

    test('the rule is applied to the normalised form', () {
      // Otherwise the app validates what the user typed and the server
      // validates what it stored, and the two disagree on the boundary.
      expect(StarterHandle.isValid(' ANN_LEE '), isTrue);
    });
  });
}
