# Changelog

## Unreleased

- `AppKeyboardInset` follows native iOS engine frames directly while retaining
  the 250 ms tween on web and other platforms, so bottom sheets do not trail
  the native keyboard (#578).

- Web Docker builds accept `BUILD_NUMBER` (default `0`) and include it in the
  served Flutter version metadata. Generated Images workflows supply the run
  number; existing projects must update their copied web Dockerfile (#566).
