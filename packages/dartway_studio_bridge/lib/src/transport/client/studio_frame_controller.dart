import '../studio_message_channel.dart';

export 'studio_frame_controller_stub.dart'
    if (dart.library.js_interop) 'studio_frame_controller_web.dart';

/// Studio-side owner of the embedded app frame: creates the iframe, registers
/// it as a platform view (render it with `HtmlElementView(viewType:)`), and
/// exposes the message channel to the app inside.
///
/// Create instances via `createStudioFrameController` from the compile-time
/// implementation; the non-web stub throws (Studio runs on web only).
abstract interface class StudioFrameController {
  /// Platform view type to pass to `HtmlElementView`.
  String get viewType;

  /// Channel to the app inside the frame (origin-locked to the app URL).
  StudioMessageChannel get channel;

  void dispose();
}
