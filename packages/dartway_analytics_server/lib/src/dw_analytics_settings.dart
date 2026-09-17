/// How analytics is kept.
final class DwAnalyticsSettings {
  const DwAnalyticsSettings({
    this.retention = const Duration(days: 180),
    this.sessionGap = const Duration(minutes: 30),
    this.cleanupInterval = const Duration(hours: 1),
  });

  /// How long an event is kept after it was received. Installs not seen for
  /// as long go with their last events.
  final Duration retention;

  /// A pause between two events of one install longer than this starts a new
  /// session — the usual definition, so the numbers compare with other tools.
  final Duration sessionGap;

  /// How often events past [retention] are removed.
  final Duration cleanupInterval;

  /// Problems with these values; empty when they are usable.
  List<String> get problems => [
    if (retention <= Duration.zero) 'analytics retention must be positive',
    if (sessionGap <= Duration.zero) 'analytics sessionGap must be positive',
    if (cleanupInterval <= Duration.zero)
      'analytics cleanupInterval must be positive',
  ];
}
