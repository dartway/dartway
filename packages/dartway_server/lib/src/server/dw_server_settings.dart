/// Limits and timings of a server. The defaults suit a mobile app on one
/// server process; every value exists because something unbounded would
/// otherwise grow.
final class DwServerSettings {
  const DwServerSettings({
    this.pingInterval = const Duration(seconds: 20),
    this.outboundLimitBytes = 8 << 20,
    this.maxInboundMessageBytes = 1 << 20,
    this.maxConcurrentCalls = 16,
    this.maxWaitingCalls = 256,
    this.closeGrace = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 15),
    this.allowedOrigins = const {},
    this.jobWorkers = 2,
    this.jobPollInterval = const Duration(seconds: 30),
    this.commandOutcomeRetention = const Duration(days: 7),
    this.alertsPerSignature = 5,
    this.alertWindow = const Duration(hours: 1),
  }) : assert(outboundLimitBytes > 0),
       assert(maxInboundMessageBytes > 0),
       assert(maxConcurrentCalls > 0),
       assert(jobWorkers >= 0);

  /// The server pings every connection at this interval; a peer that has not
  /// answered by the next ping is dropped. Relic sends no pings by default,
  /// and a dead mobile connection otherwise lingers until TCP gives up.
  final Duration pingInterval;

  /// Bytes a connection may have waiting — queued and not yet taken by its
  /// socket — when another message is sent; past it the connection is closed
  /// as a slow consumer (close code 4008). One message larger than this alone
  /// does not trip it.
  final int outboundLimitBytes;

  /// The largest inbound message; a bigger one closes the connection (1009).
  final int maxInboundMessageBytes;

  /// Calls one connection may have running at once; the rest wait in order,
  /// so a single client cannot occupy the whole database pool.
  final int maxConcurrentCalls;

  /// Calls one connection may have waiting for a slot; one more closes the
  /// connection (close code 4029) — no real client queues that many.
  final int maxWaitingCalls;

  /// How long a close handshake may take before the socket is destroyed.
  final Duration closeGrace;

  /// How long `stop()` waits for running calls and jobs.
  final Duration stopTimeout;

  /// Hosts (as in `Origin`) allowed to open the app WebSocket from a browser
  /// in addition to the server's own host — a Flutter web app served from
  /// another domain. Requests without `Origin` (native apps) are always
  /// allowed.
  final Set<String> allowedOrigins;

  /// Concurrent job executions in this process; 0 runs no jobs (a process
  /// that only serves).
  final int jobWorkers;

  /// The slowest a due job waits when its notification was lost.
  final Duration jobPollInterval;

  /// How long command outcomes are kept for idempotency (D-013).
  final Duration commandOutcomeRetention;

  /// Alerts of one failure signature per [alertWindow]; failures are logged
  /// regardless.
  final int alertsPerSignature;
  final Duration alertWindow;
}
