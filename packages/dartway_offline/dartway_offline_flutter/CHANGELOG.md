# Changelog

## 0.1.0

- Adds the generic mobile offline runtime: verified package manifests, durable downloads, local
  assets and repository snapshots, trusted time, scoped access, and an outbox.
- `DwOfflinePlugin` is the local store `dw.repo` reads and writes through. It is declared with the
  core (`DwCore(plugins: [DwOfflinePlugin(...)])`) and reached as `dw.plugins.offline`; nothing is
  registered, so nothing can stay registered after the core it belongs to is gone. Both halves
  report `null` until the runtime is initialized and again once it is disposed, leaving `dw.repo`
  network-only on the way in and on the way out.
- Both commits — the outbox enqueue and the snapshot keep — run inside a real drift transaction,
  serialized against scope activation, and the package runs the core's `DwRepoLocalWrites` and
  `DwRepoLocalReads` conformance suites.
- Manifest v2 accepts an application-calculated `leaseValidUntilUtc`. The framework verifies the
  signed boundary but carries no application-specific access categories or duration rules.
