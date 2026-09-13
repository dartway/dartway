/// Close codes of the app WebSocket.
///
/// The server closes with them and the client decides by them whether to
/// reconnect at once, back off, or stop; one declaration keeps the two sides
/// from disagreeing about a number.
abstract final class DwCloseCode {
  /// The server is stopping; reconnect.
  static const int serverStopping = 1001;

  /// A frame that is not text. A client bug: backing off is all a client can
  /// do about it.
  static const int unsupportedData = 1003;

  /// An inbound message over the server's `maxInboundMessageBytes`. A client
  /// bug, like [unsupportedData].
  static const int messageTooBig = 1009;

  /// The server failed while authenticating the connection; the reason names
  /// the incident (`dw.failed:<incident>`). Reconnect.
  static const int internalError = 1011;

  /// A message the server cannot parse as the wire protocol. A client bug:
  /// reconnecting sends it again, so the client backs off.
  static const int protocolError = 4000;

  /// The client speaks another wire version (`?v=` on the upgrade URL). The
  /// reason names the server's version (`dw.wireVersion:<n>`). Terminal:
  /// reconnecting cannot help, only another build of the app can.
  static const int unsupportedVersion = 4001;

  /// The client did not read its messages fast enough and the outbound queue
  /// passed its ceiling. Reconnect with backoff: at once would meet the same
  /// backlog.
  static const int slowConsumer = 4008;

  /// More calls waiting for a slot than the server's `maxWaitingCalls`.
  /// Reconnect with backoff, for the same reason as [slowConsumer].
  static const int tooManyCalls = 4029;

  /// The reason prefix of [unsupportedVersion].
  static const String wireVersionReason = 'dw.wireVersion:';
}
