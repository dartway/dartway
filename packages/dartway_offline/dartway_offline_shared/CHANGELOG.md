# Changelog

## 0.1.0

- The wire contract both halves of the offline family read rather than restate: the manifest
  signing frame (`DwOfflineManifestEnvelope`) and the repository content digest
  (`DwOfflineRepositoryContentRevision`).
- The digest previously lived in `dartway_serverpod_core_shared`, where every application on the
  framework carried it. Only the offline family ever reads it.
