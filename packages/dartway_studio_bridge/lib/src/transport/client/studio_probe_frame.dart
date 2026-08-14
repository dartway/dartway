import '../studio_message_channel.dart';

export 'studio_probe_frame_stub.dart'
    if (dart.library.js_interop) 'studio_probe_frame_web.dart';

/// A frame nobody has to render: opened into a hidden container of its own,
/// outside the host framework's widget tree, and closed again by whoever opened
/// it.
///
/// This is the difference from [StudioFrameController], which hands out a
/// platform view for the embedder to lay out — and therefore loads nothing
/// until the embedder does. An iframe that is not in the document does not
/// fetch its `src`, so no load means no handshake, which is why asking the
/// question through the preview's own machinery costs a 1×1 frame parked in a
/// corner of the screen for the lifetime of the app.
///
/// Create instances via `openStudioProbeFrame` from the compile-time
/// implementation; the non-web stub throws, as Studio runs on web only.
abstract interface class StudioProbeFrame {
  /// Channel to the app inside the frame (origin-locked to the app URL).
  StudioMessageChannel get channel;

  /// Closes the channel and takes the frame back out of the document.
  void dispose();
}
