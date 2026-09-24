# dartway_generator

Code generation for [DartWay](https://dartway.dev) projects — DTO codecs, registries, entity
tables and schema. It reads and writes a project's shared and server package in one run: DTO parts
and the protocol registry in the shared package, row parts and the database schema in the server
package.

Run as `dartway generate` (add `--check` to verify without writing), or directly as
`dart run dartway_generator --project <dir>` from a project's server package.

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
