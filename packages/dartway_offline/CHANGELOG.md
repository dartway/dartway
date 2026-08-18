# Changelog

## 0.1.0

- Adds the generic mobile offline runtime: verified package manifests, durable downloads, local
  assets and repository snapshots, trusted time, scoped access, and an outbox.
- Manifest v2 accepts an application-calculated `leaseValidUntilUtc`. The framework verifies the
  signed boundary but carries no application-specific access categories or duration rules.

