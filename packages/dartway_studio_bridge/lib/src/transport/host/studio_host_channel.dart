/// App-side transport factory. The implementation is chosen at compile time:
/// a web implementation talking to the embedding window, or a stub that
/// reports "not embedded" on every other platform.
///
/// Provides `isEmbeddedInStudioFrame` (web and inside an iframe) and
/// `createStudioHostChannel` (null when not embedded or not permitted).
///
/// Origin policy: with a non-empty allowlist only those origins may talk (and
/// are the only targets we post to). With an empty list, debug/profile builds
/// accept the first valid Studio message and pin its origin — zero-config
/// local development — while release builds stay dormant (secure by default).
library;

export 'studio_host_channel_stub.dart'
    if (dart.library.js_interop) 'studio_host_channel_web.dart';
