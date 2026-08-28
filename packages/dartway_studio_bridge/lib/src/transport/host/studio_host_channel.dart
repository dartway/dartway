/// App-side transport factory. The implementation is chosen at compile time:
/// a web implementation talking to the embedding window, or a stub that
/// reports "not embedded" on every other platform.
///
/// Provides `isEmbeddedInStudioFrame` (web and inside an iframe) and
/// `createStudioHostChannel` (null when not embedded). The latter takes an
/// optional `onMessageDropped`: an app that hears nothing from Studio has the
/// same problem the Studio side has, from the other end — a version mismatch
/// and a stranger's message on `window` are both simply silence otherwise.
///
/// Origin note: the channel accepts the first valid bridge message from the
/// embedding window and pins that origin for its replies. There is no origin
/// allowlist for now — zero-config local work outweighs the ceremony; an
/// embedding page can only drive what the bridge exposes (navigation, test
/// sign-in), and an explicit opt-in policy can return later if needed.
library;

export 'studio_host_channel_stub.dart'
    if (dart.library.js_interop) 'studio_host_channel_web.dart';
