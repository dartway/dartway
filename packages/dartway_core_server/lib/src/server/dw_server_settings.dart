/// Limits and timings of a server. The defaults suit a mobile app on one
/// server process; every value exists because something unbounded would
/// otherwise grow.
final class DwServerSettings {
  const DwServerSettings({
    this.minAppBuild = 0,
    this.maxBodyBytes = 1 << 20,
    this.bodyReadTimeout = const Duration(seconds: 30),
    this.pingInterval = const Duration(seconds: 20),
    this.outboundLimitBytes = 8 << 20,
    this.maxLiveMessageBytes = 64 << 10,
    this.closeGrace = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 15),
    this.allowedOrigins = const {},
    this.tokenCacheSize = 10000,
    this.tokenCacheTtl = const Duration(minutes: 1),
    this.jobWorkers = 2,
    this.jobPollInterval = const Duration(seconds: 30),
    this.commandOutcomeRetention = const Duration(days: 7),
    this.alertsPerSignature = 5,
    this.alertWindow = const Duration(hours: 1),
  }) : assert(minAppBuild >= 0),
       assert(maxBodyBytes > 0),
       assert(outboundLimitBytes > 0),
       assert(maxLiveMessageBytes > 0),
       assert(tokenCacheSize >= 0),
       assert(jobWorkers >= 0);

  /// The oldest app build this server talks to. A call whose `Dw-App-Version`
  /// build is lower — or that sends none while this is above 0 — is answered
  /// `426` with `dw.updateRequired`, and the live socket closes with
  /// `DwCloseCode.incompatible`. Read at startup, so raising it needs a
  /// restart and no release (a project reads it from its environment or its
  /// database before constructing the server).
  final int minAppBuild;

  /// The largest call body, in bytes. A handler may declare its own
  /// (`DwCallHandler`'s `maxBodyBytes`); project routes pass theirs to
  /// `DwHttpRequest.bytes`.
  final int maxBodyBytes;

  /// How long a whole body may take to arrive. A client dripping a body a
  /// byte at a time holds a connection and a buffer; this bounds both.
  final Duration bodyReadTimeout;

  /// The server pings every live socket at this interval; a peer that has not
  /// answered by the next ping is dropped. A dead mobile connection otherwise
  /// lingers until TCP gives up.
  final Duration pingInterval;

  /// Characters a live socket may have waiting — queued and not yet taken by
  /// its peer — when another message is sent; past it the socket is closed as
  /// a slow consumer (`DwCloseCode.slowConsumer`). One message larger than
  /// this alone does not trip it.
  final int outboundLimitBytes;

  /// The largest inbound live message; a bigger one closes the socket
  /// (`DwCloseCode.messageTooBig`). Live messages are a token or a channel
  /// name, so the limit is small.
  final int maxLiveMessageBytes;

  /// How long a close handshake may take before the socket is destroyed.
  final Duration closeGrace;

  /// How long `stop()` waits for running calls and jobs.
  final Duration stopTimeout;

  /// Browser origins allowed to open the live socket in addition to the
  /// origin the upgrade was sent to — full origins, as a browser sends them in
  /// `Origin`: `https://app.example.com`, `http://localhost:5000`. Scheme,
  /// host and port are all compared; the server refuses to start with an
  /// entry that is not a full origin (a bare host would silently allow every
  /// port and scheme of it).
  ///
  /// Upgrades without `Origin` (native apps) are always allowed. Calls need no
  /// such list: they are same-origin by deployment (R2.7), and a cross-origin
  /// browser call cannot pass the JSON content-type preflight, which the
  /// server never answers.
  final Set<String> allowedOrigins;

  /// Session tokens resolved to accounts kept in memory, so a call costs no
  /// query to authenticate. 0 disables the cache.
  final int tokenCacheSize;

  /// How long a resolved token is trusted without asking the database again.
  /// Revocations made by this process take effect at once; this bounds how
  /// late one made elsewhere (a seed script, another process) is noticed.
  final Duration tokenCacheTtl;

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
