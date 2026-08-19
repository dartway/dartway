/// Controls whether one repository query may use registered snapshot storage.
enum DwRepoReadStrategy {
  /// Always resolves through the backend and never persists a response.
  networkOnly,

  /// Tries the backend first, persists eligible responses, and falls back to
  /// a snapshot only for a connection failure.
  networkFirstWithSnapshot,
}
