/// What the app's realtime subscriptions are doing right now — the value
/// behind `dw.socketService.statusNotifier`.
///
/// Three states, and each one is something the client can actually observe.
/// Serverpod's own `StreamingConnectionStatus` is not reused: it describes a
/// connection that exists on its own, and under method streams there is no such
/// thing. The socket is opened when the first channel is subscribed to and
/// closed when the last one goes, so "connected with nothing subscribed" is not
/// a state that can happen — and a `connecting` state would be a guess, because
/// the client is told a stream failed but never told it succeeded.
enum DwSocketStatus {
  /// Nothing is subscribed, so there is no connection to have. Where an app
  /// sits before sign-in if every channel it follows is a signed-in one.
  idle,

  /// Every channel the app asked for is open and none has reported a failure.
  ///
  /// **Not a heartbeat.** A socket that dies silently reads as connected until
  /// the client notices, which its keep-alive puts at up to 40 seconds.
  connected,

  /// A subscription failed and is waiting to be opened again. What an offline
  /// app shows, and what it keeps showing while the retry loop runs.
  waitingToRetry,
}
