---
title: Commit the generated project contract descriptor and verify a trusted base
affects:
  dartway_generator: "0.21.0-dev.17"
  dartway_cli: "0.24.0"
---

Projects using generated shared DTOs must regenerate and commit
`<project>_shared/lib/generated/dw_contract.json` with their codecs/registry.
Never edit this descriptor by hand. CI must supply its trusted committed base
revision to `generate --check --contract-base <SHA>` and
`check --contract-base <SHA>`; keep that SHA fixed through regeneration and
feature commits. Normal check uses the configured project base-branch merge-base.

A baseline without the descriptor is adopted in the pin-move PR when every
hand-written shared package file is byte-identical to the trusted base. Regenerate
and commit the codecs/registry and descriptor in that PR. The generator excludes
its owned output (`lib/generated/**` and generated parts), the shared `pubspec.yaml`
and lock from the source comparison, so a framework pin move can establish the
first descriptor. The result prints `adopted at <base SHA>: shared contract source
unchanged; descriptor established by this change`.

If any hand-written shared file changes, the gate blocks and names the files.
Split the change: land the framework pin move with generated output and the
first descriptor, keeping hand-written shared source unchanged; make the contract
edit in a following PR, verified against the now-committed descriptor. A descriptor
already committed at the trusted base always takes precedence. No historical
dependency fetch or reproduction, setup script or adoption flag is needed.

If `projectContractVersion` reports an incompatible edit, raise the shared
package breaking line (minor below 1.0, major above zero) and regenerate. A patch
or prerelease-only bump is insufficient. Nullable/defaulted/patch additions and
new calls are accepted only by the generated codec rules; removals, renames,
changed defaults/types/result kinds and unknown data-object update groups are
conservatively breaking. Custom/unsupported codecs block verification.

This tooling gate covers generated project codecs/registry. Review domain
semantics and manual external module contracts separately. It adds no runtime
negotiation and requires no framework `dwProtocolVersion` change.
