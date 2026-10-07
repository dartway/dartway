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

A baseline without the descriptor is accepted only after its committed source
and existing dependency resolution reproduce the committed codecs/registry
exactly in disposable scratch. If it cannot be reproduced, the blocking
`contract not verified` message explains what is missing. Establish a supported,
regenerated descriptor on the trusted base first; do not seed it from the feature
tree, update historical dependencies or run project setup scripts to bypass it.

If `projectContractVersion` reports an incompatible edit, raise the shared
package breaking line (minor below 1.0, major above zero) and regenerate. A patch
or prerelease-only bump is insufficient. Nullable/defaulted/patch additions and
new calls are accepted only by the generated codec rules; removals, renames,
changed defaults/types/result kinds and unknown data-object update groups are
conservatively breaking. Custom/unsupported codecs block verification.

This tooling gate covers generated project codecs/registry. Review domain
semantics and manual external module contracts separately. It adds no runtime
negotiation and requires no framework `dwProtocolVersion` change.
