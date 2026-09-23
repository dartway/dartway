import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';
import 'dw_check_tally.dart';

/// The naming law over the contract in the shared package
/// ([DwCheckType.contractNameInvalid], #167): a DTO name has two words or
/// more (`Dw` is not one); a read is `Get…` or `List…`; a change is a verb and
/// its object, never named like a read.
///
/// The class name is the wire name — the call path — so a name fixed after
/// the first build ships is a protocol change. Read from the source, by the
/// framework base a class extends directly; a DTO extending a base of the
/// project's own is not judged, rather than guessed at.
class DwContractNamesInspector {
  DwContractNamesInspector({
    required this.sharedPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.contractNameInvalid) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.contractNameInvalid.severity);

  final Directory? sharedPackageDir;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  static const _reads = {
    'DwSingleRequest',
    'DwMaybeRequest',
    'DwListRequest',
    'DwPageRequest',
    'DwTableRequest',
    'DwWindowRequest',
  };

  static final _declaration = RegExp(
    r'^[ \t]*(?:(?:abstract|base|final|sealed|interface)\s+)*class\s+(\w+)\s*'
    r'(?:<[^{]*?>)?\s+extends\s+(Dw\w+)\b',
    multiLine: true,
  );

  /// `CustomerInvoice` → Customer, Invoice; `DwGetFileLink` → Get, File,
  /// Link; `URLVisit` → URL, Visit.
  static List<String> wordsOf(String name) =>
      RegExp(r'[A-Z]+(?![a-z])|[A-Z][a-z0-9]*|[a-z0-9]+')
          .allMatches(name.replaceFirst(RegExp(r'^Dw(?=[A-Z])'), ''))
          .map((match) => match.group(0)!)
          .toList();

  /// What is wrong with [name] as a DTO extending [base], or null.
  static String? problemWith(String name, String base) {
    final isRead = _reads.contains(base);
    final isCommand = base == 'DwActionCommand';
    if (!isRead && !isCommand && base != 'DwDataObject') return null;
    final words = wordsOf(name.replaceFirst(RegExp(r'^_+'), ''));
    if (words.length < 2) {
      return 'is one word; a contract name has two or more '
          '(`CustomerInvoice`, not `Invoice`)';
    }
    if (isRead && words.first != 'Get' && words.first != 'List') {
      return 'is a read, named `Get…` (one object) or `List…` (many)';
    }
    if (isCommand && (words.first == 'Get' || words.first == 'List')) {
      return 'is a change named like a read; a command is a verb and its '
          'object (`PayInvoice`)';
    }
    return null;
  }

  int run({DwCheckTally? tally}) {
    final shared = sharedPackageDir;
    if (!_enabled || shared == null) return 0;
    final lib = Directory(p.join(shared.path, 'lib'));
    if (!lib.existsSync()) return 0;
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.dw.dart')) {
        continue;
      }
      final content = file.readAsStringSync();
      for (final match in _declaration.allMatches(content)) {
        final name = match.group(1)!;
        final problem = problemWith(name, match.group(2)!);
        if (problem == null) continue;
        final line =
            '\n'.allMatches(content.substring(0, match.start)).length + 1;
        _findings.add(
          '`$name` $problem — '
          '${p.relative(file.path, from: shared.parent.path)}:$line',
        );
      }
    }
    if (_findings.isEmpty) return 0;
    print('\n📌 Contract names:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.contractNameInvalid.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.contractNameInvalid, _findings.length);
    return DwCheckType.contractNameInvalid.severity == DwCheckSeverity.error
        ? _findings.length
        : 0;
  }
}
