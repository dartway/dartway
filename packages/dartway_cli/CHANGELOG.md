# Changelog

## 0.1.0

- Initial release: `dartway create` (project from the canonical template), `dartway setup-ai` (AI toolkit install/update with managed-files-only overwrite), `dartway check` (built-in convention checker: errors fail the run, warnings/infos are advisory; file length is a soft signal — >120 lines info, >200 warning) and `dartway stats` (feature code-size statistics).
- `dartway check` no longer reports two things it should never have reported: a string inside a comment is prose, not a text constant (usage examples in doc comments are the most useful thing a kit widget carries, and flagging them taught authors to document less), and generated files (`*.gen.dart`, `*.g.dart`, `*.freezed.dart`) are not asked for a `part of` directive — one added to `assets.gen.dart` survives exactly until the next `flutter_gen` run.
