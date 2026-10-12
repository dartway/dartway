/// A per-peer HTTP quota for one registered call type. The first request and
/// [burst] additional requests may arrive together; thereafter [requests]
/// requests are admitted per [period], without delaying accepted calls.
///
/// State belongs to one server process, is bounded by [maxPeers], and is not
/// shared between replicas. A full state table refuses new peers until idle
/// entries expire; it never evicts an active peer and resets their quota.
final class DwCallRateLimit {
  const DwCallRateLimit({
    required this.requests,
    this.period = const Duration(minutes: 1),
    this.burst = 0,
    this.maxPeers = 10000,
  });

  final int requests;
  final Duration period;
  final int burst;
  final int maxPeers;

  /// Declaration errors, also checked in release builds before migrations.
  List<String> get problems => [
    if (requests < 1) 'requests must be positive',
    if (period <= Duration.zero) 'period must be positive',
    if (burst < 0 || burst == 0x7fffffffffffffff)
      'burst must be nonnegative and fit the quota counter',
    if (burst >= 0 &&
        burst < 0x7fffffffffffffff &&
        period.inMicroseconds > 0x7fffffffffffffff ~/ (burst + 1))
      'period and burst exceed the quota counter',
    if (maxPeers < 1) 'maxPeers must be positive',
  ];
}
