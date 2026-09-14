/// Timing policy of a `DwAppClient`. Defaults are for an app on a phone
/// network; tests shrink them.
final class DwClientOptions {
  const DwClientOptions({
    this.callTimeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.releaseDelay = const Duration(seconds: 1),
    this.liveSettleTimeout = const Duration(seconds: 3),
    this.liveIdleDelay = const Duration(seconds: 5),
  });

  /// How long a one-shot call (`fetch`, `command`) may go without an answer,
  /// counted from the call — retries after network failures included —
  /// before it completes with `DwTimeoutException`. A caller must not wait
  /// forever for a server that is not coming back.
  ///
  /// A watched request has no deadline: it keeps retrying for as long as it is
  /// watched. After this long without an answer and without data it shows
  /// `DwRequestUnreachable`, so a screen does not spin in silence; a page or
  /// window load that has not been answered in this time gives up with a
  /// `DwTimeoutException` as its load error, keeping what was loaded.
  ///
  /// The same window decides that the live socket is dead: when something was
  /// sent on it and **nothing at all** arrived for a whole window, the client
  /// drops it and reconnects. Pongs are answered beneath the socket API — in a
  /// browser invisibly — so a half-open socket would otherwise look alive.
  final Duration callTimeout;

  /// The first delay before retrying a call after a network failure, and
  /// before reconnecting the live socket. Each consecutive failure doubles
  /// it, up to [maxRetryDelay]; the actual wait is drawn between half and the
  /// whole of that value, so a server restart is not met by every client at
  /// once.
  final Duration retryDelay;

  final Duration maxRetryDelay;

  /// How long a request stays live after its last watcher left.
  ///
  /// A screen that is rebuilt, or left and re-entered quickly, closes its
  /// watch and opens an equal one; without a delay that is an unsubscribe, a
  /// subscribe and a refetch for data the client already had, live. During
  /// the delay the entry keeps its subscriptions, so what a returning watcher
  /// sees is current, not cached. [Duration.zero] releases at once.
  final Duration releaseDelay;

  /// How long a watched request with channels waits for its subscriptions
  /// before fetching.
  ///
  /// Fetching first and subscribing after would lose whatever the server
  /// publishes in between, so a request whose subscriptions are on their way
  /// fetches once they are answered. A live socket that is slow to come up
  /// must not hold the screen hostage: after this long the request fetches
  /// anyway, and fetches again when its subscriptions become active.
  final Duration liveSettleTimeout;

  /// How long the live socket stays open after the last channel was released.
  ///
  /// The socket exists only for subscriptions; an app that watches nothing
  /// live holds no connection. Navigating from one live screen to another
  /// releases one set of channels a moment before the next arrives, and the
  /// delay spares that moment a TLS handshake.
  final Duration liveIdleDelay;
}
