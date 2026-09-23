#!/usr/bin/env bash
#
# Analyze every package and run every suite — those that need no services, and,
# as a mode of their own, those that need a Postgres and an S3-compatible
# storage.
#
# The same command locally and in CI, on purpose. "I ran the tests before
# committing" and "CI runs the tests" were two different sets, and the gap
# between them is exactly where a change to one package broke a suite in
# another — the author ran what they touched, which was green, and the suite
# that failed belonged to a package they had no reason to open.
#
#   tool/checks.sh             analyze + test: needs no Docker
#   tool/checks.sh analyze     dart analyze over every resolution root
#   tool/checks.sh test        every suite that needs no services
#   tool/checks.sh services    the suites of the packages named in SERVICES,
#                              against DW_DATABASE_* and DW_STORAGE_*
#
# `services` is not run by the default: it needs the two containers below, and
# the default is what anyone can run on a laptop without them. It is not
# optional either — CI runs it on every pull request beside the other two, and
# a change to one of those packages is not tested until it is green. Asked for
# without its services, it stops before running anything and says what is
# missing: a services tier that skips is a tier that does not exist.
#
#   docker run -d --name dw10-postgres -p 127.0.0.1:55460:5432 \
#     -e POSTGRES_USER=dartway -e POSTGRES_PASSWORD=dartway postgres:17-alpine
#   docker run -d --name dw10-minio -p 127.0.0.1:55470:9000 \
#     -e MINIO_ROOT_USER=dartway -e MINIO_ROOT_PASSWORD=dartway-secret \
#     quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z server /data
#   export DW_DATABASE_HOST=127.0.0.1 DW_DATABASE_PORT=55460 \
#     DW_DATABASE_NAME=postgres DW_DATABASE_USER=dartway \
#     DW_DATABASE_PASSWORD=dartway DW_DATABASE_SSL=false \
#     DW_STORAGE_ENDPOINT=http://127.0.0.1:55470 \
#     DW_STORAGE_ACCESS_KEY=dartway DW_STORAGE_SECRET_KEY=dartway-secret

set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"
FAILED=()
UNRUN=()

# A mistyped mode must not look like a clean run. This script is invoked by hand
# as well as by CI, and "tool/checks.sh tests" printing "everything green"
# without having run anything is the worst answer a gate can give.
case "$MODE" in
  all|analyze|test|services) ;;
  *)
    echo "unknown mode: $MODE" >&2
    echo "usage: tool/checks.sh [analyze|test|services]   (default: analyze and test)" >&2
    exit 64
    ;;
esac

# The SDK this repository is written against, from `.fvmrc` — the one file that
# already says so, read rather than repeated.
#
# Checked because the gate is worthless when it runs on another SDK: a Flutter
# on `PATH` seven months old failed `dartway_core_flutter`, the example and the
# template on a widget parameter that only exists in 3.44, and the failures
# named the parameter rather than the SDK. The opposite is worse and silent:
# code written against an older SDK passes here and fails in CI, which pins the
# version. Neither answer is about the change under test.
#
# It stops rather than re-executing itself under fvm: this script also runs in
# CI, where fvm is not installed and the version is pinned by the workflow.
PINNED="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .fvmrc)"
RUNNING="$(flutter --version 2>/dev/null | sed -n '1s/^Flutter \([^ ]*\).*/\1/p')"

if [ -z "$PINNED" ]; then
  echo "cannot read the pinned Flutter version out of .fvmrc" >&2
  exit 1
fi

if [ "$RUNNING" != "$PINNED" ]; then
  echo "Flutter ${RUNNING:-not found} is on PATH; this repository is written against $PINNED" >&2
  echo "run it under the pinned SDK:  fvm exec tool/checks.sh ${1:-}" >&2
  exit 1
fi

# Suites this script deliberately does not run, each with its reason. A package
# is skipped only by being named here — anything new with a `test/` directory is
# picked up and run, which is the direction that fails loudly rather than
# quietly leaving a package uncovered.
#
# The two project servers are tier three: their suites run through `dartway
# test`, which applies the project's migrations to a Postgres and a MinIO of its
# own, in `database.yml` (pull requests and nightly). The lints fixture is not a `dart test`
# suite at all — the files under its `test/` are written to violate the rules and
# deliberately have no `main`; `dartway_lints`' own `test/example_test.dart` runs
# the analyzer over it.
# Kept as a plain list rather than an associative array: those need bash 4, and
# macOS ships 3.2 — a script that only runs in CI is the thing this is trying to
# stop being.
SKIP="\
example/dartway_example_server|a project server, run by dartway test (database.yml)
template/dartway_starter_server|a project server, run by dartway test (database.yml)
packages/dartway_lints/example|a fixture, proved by dartway_lints' example_test"

# Packages whose suites need the services, run by `services` and by nothing
# else. Named whole rather than file by file: their own support code fails a
# suite that cannot reach a service in `setUpAll`, so a package that gains such
# a suite without being named here goes red in `test` — the loud direction —
# and a list of files would be the thing that quietly falls behind.
SERVICES="\
packages/dartway_analytics_server|Postgres
packages/dartway_auth_providers_server|Postgres
packages/dartway_orm|Postgres
packages/dartway_core_server|Postgres and storage
packages/dartway_push_server|Postgres"

# The reason this package is skipped, or nothing if it is not.
skip_reason() {
  printf '%s\n' "$SKIP" | while IFS='|' read -r path reason; do
    [ "$path" = "$1" ] && printf '%s' "$reason"
  done
}

# The services this package's suites need, or nothing if they need none.
services_of() {
  printf '%s\n' "$SERVICES" | while IFS='|' read -r path needs; do
    [ "$path" = "$1" ] && printf '%s' "$needs"
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

# `run` for the analyzer, which has two ways of exiting non-zero: it found
# errors, or it never finished. A killed analysis server — jetsam under memory
# pressure, or macOS refusing a page of its snapshot — prints its own line and
# says nothing about the code, so it goes to UNRUN, not FAILED. Reporting the
# two the same way sends one reader hunting for a defect that is not in the
# diff and teaches the next that some roots "are always red here", which is
# how a real error gets waved through.
analyze_root() {
  local label="$1"; shift
  echo "── $label"
  local out status
  out="$(mktemp)"
  "$@" 2>&1 | tee "$out"
  status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    if grep -qE 'analysis server crashed|analysis server exited with code' "$out"; then
      UNRUN+=("$label")
    else
      FAILED+=("$label")
    fi
  fi
  rm -f "$out"
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
  # Errors only. The warnings that stand are in generated code
  # (`dw_updates_transport.dart`), which nobody reviews and the generator
  # rewrites — gating on it would make red mean "the generator again" — and in
  # `packages/dartway_lints/example`, a fixture written to break the lint rules,
  # whose warnings its own test counts.
  # `tool` is in here so the scripts this repository runs on itself are held
  # to the same analyzer as the code they check.
  analyze_root "packages + tool (workspace)" \
    dart analyze --no-fatal-warnings packages tool
  for package in $(packages); do
    is_member "$package" && continue
    analyze_root "$package" \
      bash -c "cd '$package' && dart analyze --no-fatal-warnings"
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
    needs="$(services_of "$package")"
    if [ -n "$needs" ]; then
      echo "── $package — in services: needs $needs"
      continue
    fi
    run "$package" bash -c "cd '$package' && $(runner_of "$package") test"
  done
}

# Stops the run, before anything is resolved or run, unless every variable the
# suites read is set and both services answer on their ports. Forty suites each
# failing in `setUpAll` say the same thing less clearly.
require_services() {
  local missing=()
  for name in DW_DATABASE_HOST DW_DATABASE_PORT DW_DATABASE_NAME \
    DW_DATABASE_USER DW_DATABASE_PASSWORD DW_DATABASE_SSL \
    DW_STORAGE_ENDPOINT DW_STORAGE_ACCESS_KEY DW_STORAGE_SECRET_KEY; do
    [ -n "${!name:-}" ] || missing+=("$name")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "services: not set: ${missing[*]}" >&2
    echo "the services mode runs against a Postgres and an S3-compatible storage;" >&2
    echo "the docker run and export lines are at the top of tool/checks.sh" >&2
    exit 2
  fi
  local storage="${DW_STORAGE_ENDPOINT#*://}"
  storage="${storage%%/*}"
  local storage_port="${storage##*:}"
  [ "$storage_port" = "$storage" ] && storage_port=80
  for target in "$DW_DATABASE_HOST:$DW_DATABASE_PORT" "${storage%:*}:$storage_port"; do
    if ! (exec 3<>"/dev/tcp/${target%:*}/${target##*:}") 2>/dev/null; then
      echo "services: nothing answers on $target" >&2
      exit 2
    fi
  done
}

service_suites() {
  echo "══ services"
  printf '%s\n' "$SERVICES" | while IFS='|' read -r package needs; do
    [ -d "$package/test" ] || { echo "$package is named in SERVICES and has no test/" >&2; exit 1; }
  done || exit 1
  for package in $(printf '%s\n' "$SERVICES" | cut -d'|' -f1); do
    run "$package ($(services_of "$package"))" \
      bash -c "cd '$package' && $(runner_of "$package") test"
  done
}

[ "$MODE" = services ] && require_services
resolve
[ "$MODE" = all ] || [ "$MODE" = analyze ] && analyze
[ "$MODE" = all ] || [ "$MODE" = test ] && test_suites
[ "$MODE" = services ] && service_suites

echo
if [ ${#FAILED[@]} -eq 0 ] && [ ${#UNRUN[@]} -eq 0 ]; then
  case "$MODE" in
    all) echo "✓ analyze and test green — the services suites are 'tool/checks.sh services'" ;;
    *) echo "✓ $MODE green" ;;
  esac
  exit 0
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "✗ failed: ${#FAILED[@]}"
  printf '  %s\n' "${FAILED[@]}"
fi
# Not green either: a root nobody analyzed is a root nobody checked. Exit 2,
# as `tool/self_check.dart` does, for a check that could not be carried out.
if [ ${#UNRUN[@]} -gt 0 ]; then
  echo "? not analyzed — the analysis server died, nothing was said about the code: ${#UNRUN[@]}"
  printf '  %s\n' "${UNRUN[@]}"
  echo "  run the root again on its own; if it dies again, look at memory and the SDK, not the diff"
fi
[ ${#FAILED[@]} -gt 0 ] && exit 1
exit 2
