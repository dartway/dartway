import 'package:dartway_generator/src/contract/descriptor.dart';
import 'package:test/test.dart';

void main() {
  test('an unmarked removal is rejected and a baseline mark permits it', () {
    final current = _contract(fields: {});
    expect(
      compareContracts(_contract(), current),
      contains(contains('OrderCard.title')),
    );
    expect(compareContracts(_contract(deprecated: true), current), isEmpty);
  });

  test('release check rejects a deprecation that is still present', () {
    final baseline = _contract(deprecated: true);
    expect(staleDeprecations(baseline, _contract(deprecated: true)), [
      'OrderCard.title',
    ]);
    expect(staleDeprecations(baseline, _contract(fields: {})), isEmpty);
  });

  test('only a tolerant baseline permits an enum addition', () {
    expect(
      compareContracts(
        _contract(open: false),
        _contract(open: false, added: true),
      ),
      isNotEmpty,
    );
    expect(
      compareContracts(
        _contract(open: true),
        _contract(open: true, added: true),
      ),
      isEmpty,
    );
  });
}

Map<String, dynamic> _contract({
  bool deprecated = false,
  bool open = true,
  bool added = false,
  Map<String, dynamic>? fields,
}) => {
  'format': 2,
  'codec': 1,
  'contractVersion': '0.1.0',
  'unverified': <Object?>[],
  'objects': {
    'OrderCard': {
      'kind': 'data',
      'identity': {'kind': 'int', 'nullable': false},
      'fields':
          fields ??
          {
            'title': {
              if (deprecated) 'deprecatedSince': '0.1.0',
              'type': {
                'kind': 'enum',
                'nullable': false,
                'values': ['unknown', 'ready', if (added) 'archived'],
                'open': open,
                'tolerant': open,
              },
            },
          },
    },
  },
};
