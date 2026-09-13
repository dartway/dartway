/// Timing policy of a `DwClient`. Defaults are for an app on a phone network;
/// tests shrink them.
final class DwClientOptions {
  const DwClientOptions({
    this.callTimeout = const Duration(seconds: 30),
    this.reconnectDelay = const Duration(milliseconds: 500),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.releaseDelay = const Duration(seconds: 1),
  });

  /// How long a one-shot call (`fetch`, `command`) waits for its answer,
  /// counted from the call — time spent queued while disconnected included —
  /// before it completes with `DwTimeoutException`. A caller must not wait
  /// forever for a server that is not coming back.
  ///
  /// The same window decides that a connection is dead: when something was
  /// sent and **nothing at all** arrived for a whole window, the client drops
  /// the socket and reconnects. The server pings every connection, but only
  /// to find dead clients: pongs are answered beneath the socket API — and in
  /// a browser invisibly — so a client cannot learn from them that the server
  /// is gone, and a half-open connection would otherwise look alive
  /// indefinitely.
  ///
  /// Watches have no deadline: they belong to the connection, are re-run on
  /// every reconnect, and show their last data meanwhile.
  final Duration callTimeout;

  /// The first reconnect delay. Each consecutive failure doubles it, up to
  /// [maxReconnectDelay]; the actual wait is drawn between half and the whole
  /// of that value, so a server restart is not met by every client at once.
  final Duration reconnectDelay;

  final Duration maxReconnectDelay;

  /// How long a request stays live after its last watcher left.
  ///
  /// A screen that is rebuilt, or left and re-entered quickly, closes its
  /// watch and opens an equal one; without a delay that is an unsubscribe, a
  /// subscribe and a refetch for data the client already had, live. During the
  /// delay the entry keeps its subscriptions, so what a returning watcher sees
  /// is current, not cached. [Duration.zero] releases at once.
  final Duration releaseDelay;
}
