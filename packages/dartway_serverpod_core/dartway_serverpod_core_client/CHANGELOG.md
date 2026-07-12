# Changelog

## 0.1.0

- First public release: generated Serverpod protocol of the DartWay core
  module (`DwModelWrapper`, `DwApiResponse`, `DwBackendFilter`, endpoint
  callers).
- `DwAuthFailReason` gains `tooManyAttempts`, `codeExpired` and `rateLimited`,
  so the client can tell the user which auth limit it hit. **Exhaustive
  switches over `DwAuthFailReason` must handle the new values.**
