---
title: The shared package's version decides which apps a server serves; DW_MIN_APP_BUILD is gone
affects:
  dartway_core_shared: "0.20.0-dev.4"
  dartway_core_server: "0.20.0-dev.4"
  dartway_generator: "0.20.0-dev.4"
---

## Who is affected

Every project. `DwServerSettings.minAppBuild` no longer exists, the generator refuses a shared
package without a `version:`, and the wire protocol moved to 2 — every installed app is shown the
update screen once, when the server that speaks it is deployed.

## What to change

1. **`<project>_shared/pubspec.yaml` declares the contract's version** — pick the line you are on;
   `0.1.0` for a project that never raised one:

       name: my_app_shared
       + version: 0.1.0

   From now on, a change that removes or renames anything an installed app sends or reads raises the
   breaking line (the minor below 1.0: `0.1.3` → `0.2.0`) in the same pull request.

2. **`<project>_server/bin/server.dart`** — drop the setting and its line in the doc comment:

       settings: DwServerSettings(
       -  minAppBuild: int.parse(env['DW_MIN_APP_BUILD'] ?? '0'),
          allowedOrigins: { … },

   and `DW_MIN_APP_BUILD` from `deploy/config.yaml`, the secret stores
   (`dart run dartway_cli:dartway secret …`) and any CI.

3. **Tests** that played a newer server with `server.minAppBuild = N` set a newer contract line
   instead:

       - final fake = FakeApp()..server.minAppBuild = 2;
       + final fake = FakeApp()..server.contractVersion = '99.0.0';

4. Raise `dartway_*` to `^0.20.0-dev.4` and run `dart run dartway_cli:dartway generate` in the
   Flutter package: `lib/generated/dw_protocol.dart` gains `contractVersion:`.

## How to check

`dart run dartway_cli:dartway generate --check` is clean, and `lib/generated/dw_protocol.dart` ends
with your shared package's version as `contractVersion:`.
