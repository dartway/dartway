import '../studio_message_channel.dart';

export 'studio_frame_controller_stub.dart'
    if (dart.library.js_interop) 'studio_frame_controller_web.dart';

/// Studio-side owner of the embedded app frame: creates the iframe, registers
/// it as a platform view (render it with `HtmlElementView(viewType:)`), and
/// exposes the message channel to the app inside.
///
/// Create instances via `createStudioFrameController` from the compile-time
/// implementation; the non-web stub throws (Studio runs on web only). It takes
/// an optional `onMessageDropped` — a diagnostic observer of the window
/// messages the channel refuses, and the only way to see them: the source check
/// compares against *this* frame's window, which nothing outside the channel
/// can reproduce once the page carries more than one frame.
abstract interface class StudioFrameController {
  /// Platform view type to pass to `HtmlElementView`.
  String get viewType;

  /// Channel to the app inside the frame (origin-locked to the app URL).
  StudioMessageChannel get channel;

  /// Whether the frame receives pointer input — for an embedder whose overlay
  /// (a dialog, a route, a drag handle) covers the frame: an iframe takes the
  /// pointer events over its area before the Flutter layer above it sees them.
  ///
  /// A new frame is interactive. Takes effect from construction, before the
  /// view is laid out; after [dispose] it does nothing.
  void setInteractive(bool interactive);

  void dispose();
}
