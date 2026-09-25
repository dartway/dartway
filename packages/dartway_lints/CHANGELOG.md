# Changelog

## 0.4.0

**BREAKING: an analyzer plugin, not a `custom_lint` plugin** (#295). On Dart 3.13 (Flutter 3.47) the legacy plugin `custom_lint` rode on crashed inside the analysis server (`Unknown request: analysis.setAnalysisRoots`): the CLI run still passed, and the rules silently stopped showing in the IDE. The same three rules now run in the analysis server's own plugin system — enabled by `plugins: dartway_lints: ^0.4.0` in `analysis_options.yaml`, fetched by the server itself, shown in the IDE and in `dart analyze`. A project no longer depends on this package or on `custom_lint`. Migration note: `docs/migrations/2026-09-23-lints-analyzer-plugin.md`.

- `flutter analyze` does not run analyzer plugins; `dart analyze --fatal-infos` is the command that fails on these rules.
- A diagnostic is suppressed as `// ignore: dartway_lints/<rule>`.
- **A project checked out under a folder named `test` is no longer exempt from `forbidden_provider_scope`.** The rule read `test` anywhere in the file's absolute path; paths are now read relative to the package's root.
- DartWay's generated DTO parts (`*.dw.dart`) are generated files too, and left alone.
- Loads on Dart 3.12 (Flutter 3.44) and 3.13 (Flutter 3.47).
- `model_rebuild_by_constructor` is removed (#103). It matched Serverpod's `SerializableModel`, which DartWay 1.0 apps no longer have, so it could not fire; and the rows it guarded now live only in server packages, where these lints do not run. The fixtures and the `serverpod_client` dependency of the example go with it.
