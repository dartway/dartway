# dartway_starter_shared

Pure Dart, no dependencies. Code that has to behave **identically** on the
server and in the app: format validation, shared enums, computation over
fields with no IO.

The package exists so a rule both sides enforce is written once. Without it the
same rule is written twice — once in `_server`, once in `_flutter` — and the
two copies drift silently, because each side is internally consistent and
nothing compares them.

## What may not go in here

**No dependency on the client package.** The server does not depend on it
either: it carries its own copy of the generated models under
`lib/src/generated`. A shared package that reached for the protocol would be
usable by exactly one of the two sides.

So: plain values in, plain values out. Each side unpacks its own models at the
call site.

No Flutter, no Serverpod, no `Session`, no IO, no database.

## Adding to it

The public surface is `lib/dartway_starter_shared.dart`; the implementation
goes under `lib/src/`. Both `_server` and `_flutter` already depend on this
package, and both Dockerfiles already copy it — a package the images do not
copy makes them unbuildable with an error three layers from its cause.
