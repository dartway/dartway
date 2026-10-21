---
name: dartway-contract
description: "Change shared DTOs, requests, commands and codes; generate codecs and preserve installed-client compatibility."
---

# DartWay — the contract (`__SHARED_PKG__`)

Pure Dart: `dartway_core_shared` and nothing from Flutter, IO, a database or the other two packages.
A rule written here (`validate()`, `matches`) runs identically on both sides; written twice, once per
side, it drifts. Samples use the package `acme_shared`, so its enums are `AcmeChannel`, `AcmeRefusal`,
`AcmeUpload`.

Open only the reference needed for the edit:

- [models.md](references/models.md) — DTO kinds, feature layout and complete filters.
- [requests.md](references/requests.md) — choose a request kind for the screen's read shape.
- [commands.md](references/commands.md) — command input, patches and answers.
- [settings-and-codes.md](references/settings-and-codes.md) — settings, refusals, channels and upload purposes.
- [generation.md](references/generation.md) — after changing a DTO, generation and installed-build compatibility.

A DTO task starts with its kind's reference and the affected code. Open generation when the
source edit is ready, and layer skills only when changing those layers.
