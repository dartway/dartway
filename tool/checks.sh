#!/usr/bin/env bash
#
# Analyze every package and run every suite that needs no services.
#
# The same command locally and in CI, on purpose. "I ran the tests before
# committing" and "CI runs the tests" were two different sets, and the gap
# between them is exactly where a change to one package broke a suite in
# another — the author ran what they touched, which was green, and the suite
# that failed belonged to a package they had no reason to open.
#
# Nothing here needs Docker. The two suites that need a database are named
# below and skipped; they are a second tier, not this one.
#
# Usage:  tool/checks.sh [analyze|test]      (default: both)

set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"
FAILED=()

# A mistyped mode must not look like a clean run. This script is invoked by hand
# as well as by CI, and "tool/checks.sh tests" printing "everything green"
# without having run anything is the worst answer a gate can give.
case "$MODE" in
  all|analyze|test) ;;
  *)
    echo "unknown mode: $MODE" >&2
    echo "usage: tool/checks.sh [analyze|test]   (default: both)" >&2
    exit 64
    ;;
esac

# Suites this script deliberately does not run, each with its reason. A package
# is skipped only by being named here — anything new with a `test/` directory is
# picked up and run, which is the direction that fails loudly rather than
# quietly leaving a package uncovered.
#
# The two database ones are a second tier, not this one: `dartway test` makes
# them runnable, but wiring them in brings Docker, an image pull and integration
# suites whose timing is the fragile part. The lints fixture is not a `dart test`
# suite at all — the files under its `test/` are written to violate the rules and
# deliberately have no `main`; its own pubspec says `dart run custom_lint` is the
# suite, and that runs below.
# Kept as a plain list rather than an associative array: those need bash 4, and
# macOS ships 3.2 — a script that only runs in CI is the thing this is trying to
# stop being.
SKIP="\
example/dartway_example_server|needs a database
template/dartway_starter_server|needs a database
packages/dartway_lints/example|verified by custom_lint, not by dart test"

# The reason this package is skipped, or nothing if it is not.
skip_reason() {
  printf '%s\n' "$SKIP" | while IFS='|' read -r path reason; do
    [ "$path" = "$1" ] && printf '%s' "$reason"
  done
}


packages() {
  find . -name pubspec.yaml \
    -not -path '*/.dart_tool/*' -not -path '*/build/*' -not -path './pubspec.yaml' \
    | sed 's|^\./||;s|/pubspec.yaml$||' | sort
}

# A workspace member resolves from the repository root; anything else carries
# its own resolution and has to be fetched and analyzed where it stands.
is_member() { grep -q '^resolution: workspace' "$1/pubspec.yaml"; }

# `flutter test` needs a Flutter package; `dart test` fails on one. The pubspec
# says which it is.
runner_of() { grep -q 'flutter_test:' "$1/pubspec.yaml" && echo flutter || echo dart; }

run() {
  local label="$1"; shift
  echo "── $label"
  if ! "$@"; then
    FAILED+=("$label")
  fi
}

resolve() {
  echo "══ resolving"
  flutter pub get >/dev/null || { echo "root pub get failed"; exit 1; }
  for package in $(packages); do
    is_member "$package" && continue
    (cd "$package" && flutter pub get >/dev/null) \
      || { echo "pub get failed in $package"; exit 1; }
  done
}

analyze() {
  echo "══ analyze"
  # Errors only. One warning stands today and it is in generated code
  # (`dw_updates_transport.dart`), which nobody reviews and the generator
  # rewrites — gating on it would make red mean "the generator again".
  # `tool` is in here so the scripts this repository runs on itself are held
  # to the same analyzer as the code they check.
  run "packages + tool (workspace)" dart analyze --no-fatal-warnings packages tool
  for package in $(packages); do
    is_member "$package" && continue
    run "$package" bash -c "cd '$package' && dart analyze --no-fatal-warnings"
  done
}

test_suites() {
  echo "══ test"
  for package in $(packages); do
    [ -d "$package/test" ] || continue
    reason="$(skip_reason "$package")"
    if [ -n "$reason" ]; then
      echo "── $package — skipped: $reason"
      continue
    fi
    run "$package" bash -c "cd '$package' && $(runner_of "$package") test"
  done
  # The linter's own suite, run the way its package declares.
  run "packages/dartway_lints/example (custom_lint)" \
    bash -c "cd packages/dartway_lints/example && dart run custom_lint"
}

resolve
[ "$MODE" = all ] || [ "$MODE" = analyze ] && analyze
[ "$MODE" = all ] || [ "$MODE" = test ] && test_suites

echo
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "✓ everything green"
  exit 0
fi
echo "✗ failed: ${#FAILED[@]}"
printf '  %s\n' "${FAILED[@]}"
exit 1
