import '../protocol/studio_bridge_message.dart';

/// A two-way message pipe between an app and Studio. Implementations wrap
/// `window.postMessage` on web; other platforms have no channel.
abstract interface class StudioMessageChannel {
  /// Decoded messages from the other side, already origin-filtered.
  Stream<StudioBridgeMessage> get messages;

  void send(StudioBridgeMessage message);

  void dispose();
}
