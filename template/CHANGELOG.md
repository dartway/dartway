# Changelog

## Unreleased

- Add optional `AppScaffold.main(quickEntry: ...)` wiring and reusable quick-sheet
  overlay/history source: stable loading height, newest-first initial layout,
  native entrance focus, web gesture primer, frozen dismissal geometry, and
  navigation/footer reveal while the keyboard closes (#579).
- Follow native iOS keyboard frames directly instead of adding a trailing tween.

- Web Docker builds accept `BUILD_NUMBER` (default `0`) and include it in the
  served Flutter version metadata. Generated Images workflows supply the run
  number; existing projects must update their copied web Dockerfile (#566).
