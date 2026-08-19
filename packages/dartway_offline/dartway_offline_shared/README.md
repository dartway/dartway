# dartway_offline_shared

The wire contract of DartWay offline packages — read by the half that signs and by the half that
verifies, so neither restates it.

- **`DwOfflineManifestEnvelope`** — the signing frame: domain separator, schema version, algorithm
  name, length-prefix framing, the exact set of envelope fields, and the unpadded base64url the
  envelope encodes bytes with.
- **`DwOfflineRepositoryContentRevision`** — the canonical digest binding a set of repository models
  to a manifest, computed the same way on both sides regardless of map or list ordering.

Plain Dart, no Flutter and no Serverpod. Depend on it directly only if you are implementing one of
the two halves; an application reaches it through `dartway_offline_server` or
`dartway_offline_flutter`.

Why a package rather than a shared file: a signing frame that drifts between the two halves does not
fail to compile. It fails as an unverifiable manifest on somebody's device, after release.
