# Changelog

## 0.1.0

- Adds canonical Ed25519 signing primitives for generic offline package manifests.
- The signing frame itself — domain separator, schema version, algorithm name, length-prefix
  framing — comes from `dartway_offline_shared`, so the signing and the verifying half cannot
  drift apart.
- Manifest v2 signs an optional absolute `leaseValidUntilUtc`; applications retain ownership of
  access categories and duration policies.
