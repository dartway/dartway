import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_contract_names.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The naming law over the contract (#167): the class name is the wire name,
/// so a name is fixed before the first build carries it.
void main() {
  group('a name', () {
    test('of one word is refused for every kind of DTO', () {
      for (final base in ['DwDataObject', 'DwActionCommand', 'DwListRequest']) {
        expect(
          DwContractNamesInspector.problemWith('Invoice', base),
          contains('one word'),
          reason: base,
        );
      }
    });

    test('Dw is not a word, and acronyms are one', () {
      expect(DwContractNamesInspector.wordsOf('DwInvoice'), ['Invoice']);
      expect(DwContractNamesInspector.wordsOf('URLVisit'), ['URL', 'Visit']);
    });

    test('of a read starts with Get or List', () {
      expect(
        DwContractNamesInspector.problemWith(
          'SearchChatMessages',
          'DwListRequest',
        ),
        contains('Get…'),
      );
      expect(
        DwContractNamesInspector.problemWith(
          'ListChatMessages',
          'DwPageRequest',
        ),
        isNull,
      );
      expect(
        DwContractNamesInspector.problemWith('GetMyProfile', 'DwSingleRequest'),
        isNull,
      );
    });

    test('of a command is not named like a read', () {
      expect(
        DwContractNamesInspector.problemWith('GetReport', 'DwActionCommand'),
        contains('named like a read'),
      );
      expect(
        DwContractNamesInspector.problemWith('PayInvoice', 'DwActionCommand'),
        isNull,
      );
    });

    test('of a class the framework does not declare a DTO is not judged', () {
      expect(
        DwContractNamesInspector.problemWith('Helper', 'DwSomethingElse'),
        isNull,
      );
    });
  });

  test('the shared package is read, and each finding names its file', () {
    final root = Directory.systemTemp.createTempSync('dw_contract_names');
    addTearDown(() => root.deleteSync(recursive: true));
    File(p.join(root.path, 'shop_shared', 'lib', 'src', 'billing.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
part 'billing.dw.dart';

final class Invoice extends DwDataObject with _\$Invoice {}

final class PayInvoice extends DwActionCommand<void> with _\$PayInvoice {}

final class FindInvoices
    extends DwListRequest<Invoice> with _\$FindInvoices {}
''');
    final inspector = DwContractNamesInspector(
      sharedPackageDir: Directory(p.join(root.path, 'shop_shared')),
    );
    expect(inspector.run(), 2);
    expect(inspector.findings, [
      allOf(contains('`Invoice`'), contains('billing.dart:3')),
      allOf(contains('`FindInvoices`'), contains('billing.dart:7')),
    ]);
    expect(DwCheckType.contractNameInvalid.severity, DwCheckSeverity.error);
  });
}
