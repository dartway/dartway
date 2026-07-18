# Flutter architecture

`dartway_starter_flutter` follows the DartWay app model:

- **Features are end-to-end** — a feature is an entry point + `widgets/` +
  `logic/`; from outside you import only its entry point.
- **Data-layer only** — reads through `ref.watchModelList` / `watchModel`,
  writes through `DwRepository.saveModel` / `deleteModel`. No repositories,
  sockets or cache invalidation.
- **Styling only through `ui_kit/`** — no raw `Color` / `TextStyle` outside it
  (enforced by `dart run custom_lint`).
- **Navigation** — enum zones with guards (`core/router/`).

See `.claude/CLAUDE.md` and the `dartway-*` skills. Record Flutter decisions
specific to this project here as they arise.
