/// App-side transport factory. The implementation is chosen at compile time:
/// a web implementation talking to the embedding window, or a stub that
/// reports "not embedded" on every other platform.
///
/// Provides `isEmbeddedInStudioFrame` (web and inside an iframe) and
/// `createStudioHostChannel` (null when not embedded).
///
/// Origin note: the channel accepts the first valid bridge message from the
/// embedding window and pins that origin for its replies. There is no origin
/// allowlist for now — zero-config local work outweighs the ceremony; an
/// embedding page can only drive what the bridge exposes (navigation, test
/// sign-in), and an explicit opt-in policy can return later if needed.
library;

export 'studio_host_channel_stub.dart'
    if (dart.library.js_interop) 'studio_host_channel_web.dart';
