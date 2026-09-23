import 'dw_check_type.dart';

/// What one `dartway check` run found, by check — every section's findings,
/// not the last section's.
///
/// Each inspector prints its own section and adds what it printed here; the
/// command prints the tally once, at the end, beside the verdict. The tally
/// used to belong to the Flutter inspector, which knew nothing of the
/// sections printed before it: a layout error was shown, counted in the
/// verdict and missing from `By check`, and the summary people copy from
/// named three errors of four (#287).
final class DwCheckTally {
  final Map<DwCheckType, int> _counts = {};

  /// Records [count] findings of [type].
  void add(DwCheckType type, int count) {
    if (count <= 0) return;
    _counts[type] = (_counts[type] ?? 0) + count;
  }

  /// Findings by check, in the order they were first recorded.
  Map<DwCheckType, int> get counts => Map.unmodifiable(_counts);

  /// The findings that fail the check.
  int get errors => _counts.entries
      .where((entry) => entry.key.severity == DwCheckSeverity.error)
      .fold(0, (sum, entry) => sum + entry.value);

  /// `📊 By check:` and a line per check, or nothing when nothing was found.
  List<String> get summary => _counts.isEmpty
      ? const []
      : [
          '📊 By check:',
          for (final MapEntry(key: type, value: count) in _counts.entries)
            '• [${type.severity.name.toUpperCase()}] ${type.name} — $count',
        ];
}
