# dartway_generator

Code generation for [DartWay](https://dartway.dev) projects — DTO codecs, registries, entity
tables and schema. It reads and writes a project's shared and server package in one run: DTO parts
the protocol registry and sorted `lib/generated/dw_contract.json` in the shared package, row parts and the database schema in the server
package.

Run as `dartway generate` (add `--check --contract-base <trusted-SHA>` to verify without writing), or directly as
`dart run dartway_generator --project <dir>` from a project's server package.

The compatibility gate compares source-derived codec models with Git objects at a fixed committed
baseline, reusing the shared package breaking line. Incompatible or unverified results fail;
regeneration cannot silently approve a breaking contract. Without a committed descriptor,
unchanged hand-written shared source and resolved in-repo path dependencies permit adoption
in the pin-move PR. Each package excludes its pubspec and lock; shared output ownership is exactly
the current emitted paths plus header-bearing `.dw.dart` parts judged from base bytes. Hand-written
files under `lib/generated/` are compared. Git blob IDs apply clean/eol filters; framework
git-subpath and external dependencies remain outside the comparison. Changed source blocks: land the pin move
and descriptor first, then edit the contract in a following PR. No project setup scripts,
historical dependency upgrades or runtime negotiation are added. Coverage excludes
handler/domain semantics and manually composed external modules. Checks default to the configured
project base-branch merge-base; CI supplies its trusted base SHA explicitly.

## Where it sits

`dartway_generator` is one of the six packages of the core family, versioned in lockstep, but it is
a **dev tool**, not a runtime dependency: a project's server package depends on it under
`dev_dependencies`, pinned by the lock file, so generation always matches the `dartway_core_shared`
and `dartway_orm` the project builds against. It is not a workspace member of this monorepo either,
for the same reason a project pins it: it carries its own `analyzer` version.

`dartway create` wires this up already — this package is not something you add by hand to a
project.

## Documentation

The full documentation lives in the framework's repository, at
[`docs/`](https://github.com/dartway/dartway/tree/master/docs) — start at
[`docs/2-core/`](https://github.com/dartway/dartway/tree/master/docs/2-core) for data objects and
generation, or [`docs/5-tooling/`](https://github.com/dartway/dartway/tree/master/docs/5-tooling)
for the CLI commands that run it.
