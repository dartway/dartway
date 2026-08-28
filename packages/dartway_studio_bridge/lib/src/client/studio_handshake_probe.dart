import 'dart:async';

import '../protocol/studio_bridge_message.dart';
import '../transport/client/studio_probe_frame.dart';
import '../transport/studio_message_channel.dart';
import '../transport/studio_message_drop.dart';
import 'studio_bridge_client.dart';

/// What came back from one handshake — the three answers a preview cannot tell
/// apart, because all three of them look like an empty frame.
enum StudioHandshakeResult {
  /// The app answered and took the token: there is a bridge here, and this
  /// Studio may drive it.
  accepted,

  /// The app answered and refused the token it was shown. The token parsed, so
  /// it came from something that knows the format — in practice from Studio
  /// itself, which signs correctly. Read it as "the signature is stale or the
  /// key is wrong", not as "the app is broken".
  ///
  /// Only apps built against a bridge that knows [ConnectRefusedMessage] send
  /// this. An older one refuses in silence and shows up as [silent] — the same
  /// answer it gave before this existed, which is the whole reason the protocol
  /// version did not move.
  rejected,

  /// Nobody answered before the timeout, and this outcome is honestly several
  /// at once: the app carries no bridge, the page never loaded, the deployment
  /// forbids being framed, or it is an older build refusing in silence.
  ///
  /// **Those cannot be told apart from here.** Cross-origin, a frame that
  /// stayed empty and a frame that loaded an app with nothing to say are the
  /// same silence — the probe has no read access to what is inside. Whoever
  /// needs the distinction gets it *before* this call, from steps that do not
  /// involve the bridge: fetch the URL to see whether the page is served at
  /// all, and check its `frame-ancestors` / `X-Frame-Options` to see whether
  /// embedding is permitted. Do not expect [silent] to grow more precise later;
  /// it is as precise as the browser lets it be.
  silent,
}

/// One handshake with the app at [appUrl], and nothing else.
///
/// The frame is opened and closed inside: the caller neither renders it nor
/// needs to know it exists. That is the point — the bridge's preview frame is a
/// platform view, so it loads nothing until whoever embeds it lays it out, and
/// asking "do you recognise me?" through it meant keeping a 1×1 frame parked on
/// screen for the lifetime of the app. This owns its element instead.
///
/// One question, one token, one answer. [accessToken] is asked exactly once —
/// a probe is a single connect attempt, however many times the message has to
/// be repeated at a frame that is still loading — and nothing retries: an
/// answer that has not arrived within [timeout] is [StudioHandshakeResult.silent].
///
/// [StudioHandshakeResult.silent] stays as coarse as it is documented to be,
/// but it is no longer the only thing this call can tell you: pass
/// [onMessageDropped] and the frame's channel reports what it refused on the
/// way — an app answering at another protocol version arrives there, as
/// [StudioMessageDropReason.versionMismatch], rather than as more silence.
///
/// Throws whatever [accessToken] throws. A supplier that cannot produce a token
/// leaves the question unasked, and reporting that as silence would blame the
/// app for something on this side.
///
/// Web only; on any other platform the underlying frame throws
/// [UnsupportedError], as Studio runs on web.
Future<StudioHandshakeResult> probeStudioBridge({
  required String appUrl,
  StudioAccessTokenSupplier? accessToken,
  Duration timeout = const Duration(seconds: 10),
  StudioMessageDropObserver? onMessageDropped,
}) async {
  final frame = openStudioProbeFrame(
    appUrl: appUrl,
    onMessageDropped: onMessageDropped,
  );
  try {
    return await runStudioHandshake(
      frame.channel,
      accessToken: accessToken,
      timeout: timeout,
    );
  } finally {
    frame.dispose();
  }
}

/// The handshake itself, over a [channel] somebody else owns and disposes —
/// what [probeStudioBridge] is once the frame is taken out of it.
///
/// Presents a token, then waits for one of the three outcomes. The connect
/// message is sent again on every `appReady`, because the ordinary case is
/// racing a frame that has not finished loading: the app was not listening when
/// the first one went out, and announces itself the moment it attaches.
///
/// Cancels its own subscription on the way out and leaves [channel] otherwise
/// untouched.
Future<StudioHandshakeResult> runStudioHandshake(
  StudioMessageChannel channel, {
  StudioAccessTokenSupplier? accessToken,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final answer = Completer<StudioHandshakeResult>();
  String? token;

  final subscription = channel.messages.listen((message) {
    if (answer.isCompleted) return;
    switch (message) {
      case ManifestMessage():
        answer.complete(StudioHandshakeResult.accepted);
      case ConnectRefusedMessage():
        answer.complete(StudioHandshakeResult.rejected);
      case AppReadyMessage():
        // The app attached only now, so the connect below was spoken into an
        // empty frame. Same token, same question, asked again to somebody who
        // is finally there to hear it. (If the token has not arrived yet, the
        // send that follows this listener covers the case anyway.)
        if (token case final presented?) {
          channel.send(StudioConnectMessage(accessToken: presented));
        }
      default:
        break; // Studio → app messages echoed back, and reports we did not ask
      // for, are none of a probe's business.
    }
  });

  try {
    // Awaited before the clock starts: [timeout] is how long the app is given
    // to answer, not how long this side takes to produce a token.
    token = await accessToken?.call() ?? '';
    channel.send(StudioConnectMessage(accessToken: token));
    return await answer.future.timeout(
      timeout,
      onTimeout: () => StudioHandshakeResult.silent,
    );
  } finally {
    unawaited(subscription.cancel());
  }
}
