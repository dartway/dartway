import '../http/dw_call_rate_limit.dart';

/// Limits and timings of a server. The defaults suit a mobile app on one
/// server process; every value exists because something unbounded would
/// otherwise grow.
final class DwServerSettings {
  const DwServerSettings({
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
    this.failedJobRetention = const Duration(days: 30),
    this.alertsPerSignature = 5,
    this.alertWindow = const Duration(hours: 1),
    this.alertsPerMinute = 10,
    this.alertPollInterval = const Duration(seconds: 5),
    this.alertProject,
    this.alertEnvironment,
    this.outboundTimeout = const Duration(seconds: 30),
    this.outboundMaxResponseBytes = 10 << 20,
    this.callRateLimits = const {},
    this.trustedProxyNetworks = const [],
    this.behindProxy = false,
    this.deploymentVersion,
    this.slowCallThreshold = const Duration(seconds: 1),
    this.strictBounds = false,
    this.largeResponseBytes = 256 << 10,
    this.boundWarningInterval = const Duration(hours: 1),
  }) : assert(maxBodyBytes > 0),
       assert(largeResponseBytes > 0),
       assert(outboundLimitBytes > 0),
       assert(maxLiveMessageBytes > 0),
       assert(tokenCacheSize >= 0),
       assert(jobWorkers >= 0),
       assert(alertsPerMinute > 0);

  /// The largest call body, in bytes. A handler may declare its own
  /// (`DwCallHandler`'s `maxBodyBytes`); project routes pass theirs to
  /// `DwHttpRequest.bytes`.
  final int maxBodyBytes;

  /// Per-peer quotas, keyed by registered request or command class. Checked
  /// after compatibility and call lookup, before body reading or database work.
  /// Health, live sockets and in-process calls are not charged.
  final Map<Type, DwCallRateLimit> callRateLimits;

  /// Explicit IPv4/IPv6 CIDRs whose forwarding headers may be trusted. With
  /// no trusted networks, X-Forwarded-For is ignored. Never trust 0.0.0.0/0
  /// or ::/0. Walk the header from the transport peer right to left, stopping
  /// at the first untrusted address; client-supplied prefixes cannot choose it.
  final List<String> trustedProxyNetworks;

  /// A deployment behind an ingress must declare trusted networks before
  /// enabling peer quotas, rather than accidentally limiting every user as
  /// one proxy. This declaration is validated before migrations or listening.
  final bool behindProxy;

  /// Immutable revision reported by health probes. Native Kamal provides
  /// KAMAL_VERSION; local servers may omit it. It grants no access.
  final String? deploymentVersion;

  /// A call answered slower than this is logged as a warning, with its wire
  /// name, status, time and answer size. The logger filters the chosen level. Every
  /// other call is the same line at debug. Timed from the request's arrival
  /// to the encoded answer, so a slow body counts too.
  final Duration slowCallThreshold;

  /// What a `list` handler answering more items than its request's
  /// `maxItems` does: `true` fails the call, naming the request and the count
  /// — what tests (`DwTestServer`, whatever this says) and a development
  /// server (`DW_STRICT_BOUNDS` in `deploy/config.yaml > local`) want, where
  /// the list that outgrew its bound is found by whoever made it; `false`
  /// serves the whole list and logs a warning with the request, the count and
  /// the response size, at most once per request per [boundWarningInterval].
  /// The list is never cut short: a silently shorter list is a wrong answer.
  final bool strictBounds;

  /// A call response above this many bytes is logged as a warning naming the
  /// call, at most once per call per [boundWarningInterval]: a read that grew
  /// into megabytes is otherwise noticed by its users first.
  final int largeResponseBytes;

  /// How often one request's bound breach, or one call's large response, is
  /// logged again.
  final Duration boundWarningInterval;

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
  /// such list: they are same-origin by deployment (`docs/4-server/app-server.md`
  /// "Same origin"), and a cross-origin
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

  /// How long a job that ran out of attempts stays in `dw_job` for the
  /// operator, counted from when it failed.
  ///
  /// A failed job is kept on purpose: its payload and `last_error` are what an
  /// operator reads to decide whether to re-enqueue it, and each failure was
  /// already alerted. But nothing re-enqueues on its own, so without a bound the
  /// rows only accumulate — a job failing on every run of a recurring schedule
  /// adds one an hour for as long as the server lives.
  final Duration failedJobRetention;

  /// Alerts of one failure signature per [alertWindow]; failures are logged
  /// regardless.
  final int alertsPerSignature;
  final Duration alertWindow;

  /// Alerts of any signatures a minute; past it an incident is only logged,
  /// and the next alert says how many were held back. Below the channel's own
  /// limit (Telegram: 20 a minute per group), so its refusals never drop one.
  final int alertsPerMinute;
  final Duration alertPollInterval;
  final String? alertProject;
  final String? alertEnvironment;

  /// How long one outbound request (`ctx.http`) may take, from connecting to
  /// the answer's last byte, unless the call names its own. A provider that
  /// stops answering otherwise holds the handler, the job worker and the
  /// connection for as long as TCP lets it.
  final Duration outboundTimeout;

  /// The largest response body one outbound request (`ctx.http`) reads,
  /// unless the call names its own; past it the exchange is abandoned with a
  /// `DwOutboundException`. The answer is held in memory whole, so a provider
  /// that streams without end would otherwise take the process with it.
  final int outboundMaxResponseBytes;
}
