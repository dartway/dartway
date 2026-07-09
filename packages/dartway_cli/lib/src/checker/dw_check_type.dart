enum DwCheckSeverity { info, warning, error }

/// DartWay convention checks. Severity model:
/// - error — a convention is broken, fails the check (non-zero exit);
/// - warning — undesirable, should be looked at, does not fail the check;
/// - info — a nudge, purely informational.
enum DwCheckType {
  /// A file inside `ui_kit/` without the `part of '../ui_kit.dart'` directive.
  uiKitPartMissing,

  /// A text constant inside `ui_kit/` (texts belong to features/l10n).
  uiKitContainsText,

  /// Raw styles (Color/TextStyle/BorderRadius/theme access) outside `ui_kit/`.
  forbiddenUiUsage,

  /// Importing `ui_kit/*` files directly instead of the `ui_kit.dart` barrel.
  forbiddenUiKitImport,

  /// A feature folder with more than one root file, or folders other than
  /// `widgets/` and `logic/`.
  invalidFeatureStructure,

  /// A file longer than 120 lines — undesirable, not critical. A meaningful
  /// 220-line file beats a pointless split.
  fileLong,

  /// A file longer than 200 lines — worth restructuring.
  fileTooLong,

  /// Importing `widgets/` or `logic/` of another feature (only feature entry
  /// points are public).
  forbiddenFeatureImport;

  DwCheckSeverity get severity => switch (this) {
        DwCheckType.fileLong => DwCheckSeverity.info,
        DwCheckType.uiKitContainsText ||
        DwCheckType.fileTooLong =>
          DwCheckSeverity.warning,
        _ => DwCheckSeverity.error,
      };

  String get reportLabel => switch (severity) {
        DwCheckSeverity.info => 'ℹ️ INFO',
        DwCheckSeverity.warning => '⚠️ WARNING',
        DwCheckSeverity.error => '❌ ERROR',
      };
}
