import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Regression for #520: the shipped instructions must not recommend changing
/// a released schema in the same deploy that changes its readers.
void main() {
  var repository = Directory.current.absolute;
  while (!Directory(p.join(repository.path, 'toolkit')).existsSync()) {
    if (repository.parent.path == repository.path) {
      throw StateError('no toolkit/ above ${Directory.current.path}');
    }
    repository = repository.parent;
  }
  String skill(String name) => File(
    p.join(repository.path, 'toolkit/skills/$name/SKILL.md'),
  ).readAsStringSync();
  final migrations = skill('dartway-migrations');

  test('expand/contract guidance precedes the migration decisions', () {
    final rule = migrations.indexOf('## Expand, then contract');
    expect(rule, greaterThanOrEqualTo(0));
    expect(migrations.split('## Expand, then contract'), hasLength(2));
    expect(rule, lessThan(migrations.indexOf('| Decision |')));
    final guidance = migrations.substring(rule).split('## The cycle').first;
    expect(guidance, contains('deploy to production'));
    expect(guidance, contains("previous release's code must run"));
    expect(guidance, contains('one release later'));
    expect(guidance, contains('Release N+1: drop the old'));
  });

  test('each contracting decision points to the release rule', () {
    final rows = migrations.split('\n').where((line) {
      return RegExp(
        r'^\s*\| (drop table|drop column|make a column NOT NULL|change a type)',
      ).hasMatch(line);
    }).toList();
    expect(rows, hasLength(4));
    for (final row in rows) {
      expect(row, contains('](#expand-then-contract)'), reason: row);
      expect(row, contains('in the same release, expand instead'), reason: row);
      if (row.contains('renameColumn') || row.contains('RENAME TO')) {
        expect(row, contains('no released code reads'), reason: row);
      }
    }
    final addition = migrations
        .split('\n')
        .singleWhere(
          (line) => line.contains('| add a NOT NULL column to rows |'),
        );
    expect(addition, contains('previous code does not insert'));
    expect(addition, contains('otherwise the column needs a default'));
  });

  test('finish stops a contraction shipped with its reader change', () {
    final stops = skill('dartway-finish')
        .split('**Stops**')
        .last
        .split('**Code shape')
        .first
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(
      stops,
      contains(
        'a contracting migration (drop, rename, type change, NOT NULL) in the '
        'same change as the code that stops using the old shape',
      ),
    );
  });
}
