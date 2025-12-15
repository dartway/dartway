enum DwFlutterCheckSeverity { info, warning, error }

enum DwFlutterCheckType {
  uiKitPartMissing,
  uiKitContainsText,
  forbiddenUiUsage,
  forbiddenUiKitImport,
  invalidFeatureStructure,
  fileTooLong,
  forbiddenFeatureImport;

  DwFlutterCheckSeverity get severity => switch (this) {
        DwFlutterCheckType.uiKitContainsText ||
        DwFlutterCheckType.fileTooLong =>
          DwFlutterCheckSeverity.warning, // Мягкое предупреждение
        _ => DwFlutterCheckSeverity.error,
      };

  String get reportLabel => switch (severity) {
        DwFlutterCheckSeverity.info => 'ℹ️ INFO',
        DwFlutterCheckSeverity.warning => '⚠️ WARNING',
        DwFlutterCheckSeverity.error => '❌ ERROR',
      };
}
