import '../studio_message_drop.dart';

/// Who the app's side of the bridge listens to, and where it answers.
///
/// The app runs inside a frame and hears every `message` event of its window:
/// from the Studio that embedded it, from a frame it embeds itself (Studio
/// inside a preview inside Studio is a normal day), and from any page that
/// can reach the window at all. Only one of those is the peer.
///
/// Two rules, and both were once missing:
///
/// - **the message comes from the parent frame**, checked by identity of the
///   window object, not by its origin — an origin is a string anybody can
///   have, and a grandchild frame on the same origin is not the peer;
/// - **the origin is pinned to the first accepted message.** Afterwards a
///   message from another origin is refused rather than followed: the parent
///   navigating elsewhere ends the session, it does not move it. Without the
///   pin, anything that spoke between the token check and the manifest became
///   the address the manifest — the passports of every screen — was sent to.
///
/// Kept out of the web channel so that a VM test can reach it: the channel
/// itself exists only where `dart:js_interop` does.
final class StudioHostPeer {
  /// The origin of the peer, once one has been accepted. Until then the app
  /// answers `*`: the handshake has to start somewhere, and what it says
  /// (that an app is here) is no secret.
  String? get origin => _origin;
  String? _origin;

  /// Why this window message is not the peer's, or null when it is.
  StudioMessageDropReason? refuse({
    required bool fromParent,
    required String origin,
  }) {
    if (!fromParent) return StudioMessageDropReason.foreignSource;
    final pinned = _origin;
    if (pinned != null && origin != pinned) {
      return StudioMessageDropReason.foreignOrigin;
    }
    return null;
  }

  /// Records that a bridge message from [origin] was accepted — the first one
  /// pins it.
  void accepted(String origin) => _origin ??= origin;
}
