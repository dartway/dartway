/// Close codes of the live WebSocket (`/dw/live`).
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

  /// An inbound message over the server's limit. A client bug, like
  /// [unsupportedData].
  static const int messageTooBig = 1009;

  /// The server failed while serving the connection; the reason names the
  /// incident (`dw.failed:<incident>`). Reconnect.
  static const int internalError = 1011;

  /// A message the server cannot parse as a live message. A client bug:
  /// reconnecting sends it again, so the client backs off.
  static const int protocolError = 4000;

  /// This build cannot talk to this server — the live counterpart of an HTTP
  /// `426`, since a browser cannot read the status of a refused upgrade. The
  /// reason is the refusal code (`dw.updateRequired` or
  /// `dw.protocolUnsupported`). Terminal: reconnecting cannot help, only
  /// another build of the app can.
  static const int incompatible = 4026;

  /// The client did not read its messages fast enough and the outbound queue
  /// passed its ceiling. Reconnect with backoff: at once would meet the same
  /// backlog.
  static const int slowConsumer = 4008;
}
