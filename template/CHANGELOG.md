# Changelog

## Unreleased

- Web Docker builds accept `BUILD_NUMBER` (default `0`) and include it in the
  served Flutter version metadata. Generated Images workflows supply the run
  number; existing projects must update their copied web Dockerfile (#566).
