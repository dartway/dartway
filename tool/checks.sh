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
#   tool/checks.sh analyze     dart analyze over every resolution root, and
#                              dartway check over template/ and example/
#   tool/checks.sh test        every suite that needs no services, the suites
#                              of the packages named in BROWSER again in Chrome,
#                              and every `js/*` npm package (typecheck,
#                              node --test, build)
#   tool/checks.sh services    the suites of the packages named in SERVICES,
#                              against DW_DATABASE_* and DW_STORAGE_*
#
# DW_CHECKS_ONLY narrows a mode to what it names, space-separated: a package
# path, as `packages()` prints it, or `js/*`, runs the package's whole suite;
# the path of a `_test.dart` file runs that file alone. CI sets it per job to
# what `tool/affected.dart` says a pull request can break — for `analyze`, the
# packages whose code it reaches, and the projects `dartway check` covers when
# one of their packages is among them. The same works locally:
#
#   DW_CHECKS_ONLY="$(dart run tool/affected.dart --base origin/master)" \
#     tool/checks.sh test
#   DW_CHECKS_ONLY="$(dart run tool/affected.dart --base origin/master \
#     --shard analyze)" tool/checks.sh analyze
#
# Unset, everything runs.
#
# Suites, analyzer roots and project checks run side by side, DW_CHECKS_JOBS
# at a time (the machine's processors by default); each one's output is
# printed whole when it ends, in the order they started. DW_TEST_PART cuts a
# `test` run across several jobs (below).
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
#   docker run -d --name dw10-storage -p 127.0.0.1:55470:9000 \
#     -e RUSTFS_ACCESS_KEY=dartway -e RUSTFS_SECRET_KEY=dartway-secret \
#     rustfs/rustfs:1.0.0 /data
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
# test`, which applies the project's migrations to a Postgres and a storage of
# its own, in `database.yml` (pull requests and nightly). The lints fixture is not a `dart test`
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

# Packages whose suites also run in a browser, by `test` after the VM run. A
# test that needs the web engine — a platform view, `dart:ui_web`, a real DOM
# element — is `@TestOn('browser')`, and the VM run skips it without a word: a
# package is named here so that skip is not the only run it gets. The whole
# suite runs in Chrome rather than the browser files alone: the code it shares
# with the VM ships to the web, and is proved on the web compiler too (D-136).
BROWSER="\
packages/dartway_studio_bridge|the preview frame's iframe behind a platform view"

# A name in DW_CHECKS_ONLY that is neither a package nor a test file stops
# the run: a typo must not read as a selection with nothing to do.
for entry in ${DW_CHECKS_ONLY:-}; do
  case "$entry" in
    *_test.dart) [ -f "$entry" ] && continue ;;
    *) { [ -f "$entry/pubspec.yaml" ] || [ -f "$entry/package.json" ]; } && continue ;;
  esac
  echo "DW_CHECKS_ONLY names $entry, which is not a package or a test file" >&2
  exit 64
done

# DW_TEST_PART=i/n: this run is the i-th of n jobs over one selection, and
# `test` runs every n-th of the suites that run, from the i-th — or, when
# there is one, the i-th n-th of its tests. Split here, not by whoever picks
# the selection: only this script knows which of the suites it names run
# here, are skipped or need the services.
PART="${DW_TEST_PART:-1/1}"
PART_INDEX="${PART%/*}"
PART_COUNT="${PART#*/}"
case "$PART_INDEX/$PART_COUNT" in
  [1-9]*/[1-9]*) [ "$PART_INDEX" -le "$PART_COUNT" ] 2>/dev/null ;;
  *) false ;;
esac || { echo "DW_TEST_PART takes i/n, 1 <= i <= n: $PART" >&2; exit 64; }

# Whether this package's whole suite runs: always when DW_CHECKS_ONLY is
# unset, when it names the package when it is set.
selected() {
  [ -z "${DW_CHECKS_ONLY+set}" ] && return 0
  case " $DW_CHECKS_ONLY " in *" $1 "*) return 0 ;; esac
  return 1
}

# The test files of this package DW_CHECKS_ONLY names, relative to the
# package, one per line.
selected_files() {
  local entry
  for entry in ${DW_CHECKS_ONLY:-}; do
    case "$entry" in "$1"/test/*_test.dart) printf '%s\n' "${entry#"$1"/}" ;; esac
  done
}

# Whether anything of this package runs: its whole suite or a file of it.
touched() { selected "$1" || [ -n "$(selected_files "$1")" ]; }

# Checks run side by side, DW_CHECKS_JOBS at a time. Each writes to a log of
# its own, printed whole when the check ends; `drain` waits for all of them in
# the order they started and records the failures, so the output reads as the
# sequential run did. Plain arrays and a `jobs` count rather than `wait -n`:
# bash 3.2 has neither associative arrays nor `wait -n`.
JOBS="${DW_CHECKS_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
POOL_PIDS=()
POOL_LABELS=()
POOL_LOGS=()
POOL_KINDS=()
POOL_COUNT="$(mktemp)"
trap 'rm -f "$POOL_COUNT"' EXIT

# spawn <kind> <label> <command...>: runs the command in the background, once
# fewer than DW_CHECKS_JOBS are running. <kind> says how `drain` reads a
# failure: `analyze` tells a dead analysis server from errors, `part` takes
# "no tests ran" (exit 79) as a part that got none of the suite's tests, `js` wants a non-zero test count, anything else fails on a non-zero exit.
spawn() {
  local kind="$1" label="$2"; shift 2
  while jobs -rp >"$POOL_COUNT" && [ "$(wc -l <"$POOL_COUNT")" -ge "$JOBS" ]; do
    sleep 1
  done
  local log
  log="$(mktemp)"
  (
    started=$SECONDS
    "$@"
    status=$?
    echo "($((SECONDS - started)) s)"
    exit $status
  ) >"$log" 2>&1 &
  POOL_PIDS+=($!)
  POOL_LABELS+=("$label")
  POOL_LOGS+=("$log")
  POOL_KINDS+=("$kind")
  echo "   started: $label"
}

drain() {
  local i=0 status log label
  while [ $i -lt ${#POOL_PIDS[@]} ]; do
    wait "${POOL_PIDS[$i]}"
    status=$?
    log="${POOL_LOGS[$i]}"
    label="${POOL_LABELS[$i]}"
    echo "── $label"
    cat "$log"
    case "${POOL_KINDS[$i]}:$status" in
      part:79) ;;
      *:0)
        if [ "${POOL_KINDS[$i]}" = js ] && ! grep -qE '^# tests [1-9][0-9]*$' "$log"; then
          # A version below the floor is refused before the run; this is the
          # second net — a glob that stopped matching (a renamed test/
          # directory, say) must not read as green either. Same reasoning as
          # the analyzer's UNRUN: a suite nobody ran is not a suite that
          # passed.
          echo "$label: npm run check exited 0 but ran no tests" >&2
          FAILED+=("$label — ran 0 tests")
        fi
        ;;
      analyze:*)
        # The analyzer has two ways of exiting non-zero: it found errors, or
        # it never finished. A killed analysis server — jetsam under memory
        # pressure, or macOS refusing a page of its snapshot — prints its own
        # line and says nothing about the code, so it goes to UNRUN, not
        # FAILED. Reporting the two the same way sends one reader hunting for
        # a defect that is not in the diff and teaches the next that some
        # roots "are always red here", which is how a real error gets waved
        # through.
        if grep -qE 'analysis server crashed|analysis server exited with code' "$log"; then
          UNRUN+=("$label")
        else
          FAILED+=("$label")
        fi
        ;;
      *) FAILED+=("$label") ;;
    esac
    rm -f "$log"
    i=$((i + 1))
  done
  POOL_PIDS=()
  POOL_LABELS=()
  POOL_LOGS=()
  POOL_KINDS=()
}

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
  # Errors only. The warnings that stand are in
  # `packages/dartway_lints/example`, a fixture written to break the lint rules,
  # whose warnings its own test counts.
  # `tool` is in here so the scripts this repository runs on itself are held
  # to the same analyzer as the code they check.
  # One analyzer for the workspace members DW_CHECKS_ONLY names — one
  # resolution, so one process — and one for each other root.
  local members=() package
  if [ -z "${DW_CHECKS_ONLY+set}" ]; then
    members=(packages tool)
  else
    for package in $(packages); do
      is_member "$package" && selected "$package" && members+=("$package")
    done
  fi
  if [ ${#members[@]} -gt 0 ]; then
    spawn analyze "workspace: ${members[*]}" \
      dart analyze --no-fatal-warnings "${members[@]}"
  fi
  for package in $(packages); do
    is_member "$package" && continue
    selected "$package" || continue
    spawn analyze "$package" \
      bash -c "cd '$package' && dart analyze --no-fatal-warnings"
  done
}

test_suites() {
  echo "══ test"
  # package|file, file empty for the whole suite.
  local items=() item package file files runner k=0 split= kind=suite
  for package in $(packages); do
    [ -d "$package/test" ] || continue
    touched "$package" || continue
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
    if selected "$package"; then
      items+=("$package|")
    else
      for file in $(selected_files "$package"); do items+=("$package|$file"); done
    fi
  done
  # One suite for several parts: they split its tests, and a part that gets
  # none exits 79.
  if [ "$PART_COUNT" -gt 1 ] && [ ${#items[@]} -eq 1 ]; then
    split="--total-shards $PART_COUNT --shard-index $((PART_INDEX - 1))"
    kind=part
  fi
  local kept=()
  for item in ${items[@]+"${items[@]}"}; do
    if [ -n "$split" ] || [ $((k % PART_COUNT)) -eq $((PART_INDEX - 1)) ]; then
      kept+=("$item")
    fi
    k=$((k + 1))
  done
  # Items of a package are consecutive: each package's share runs as one.
  package=
  files=
  for item in ${kept[@]+"${kept[@]}"} "|"; do
    if [ "${item%%|*}" != "$package" ]; then
      if [ -n "$package" ]; then
        runner="$(runner_of "$package")"
        spawn "$kind" "$package${files:+ (${files# })}${split:+ — part $PART}" \
          bash -c "cd '$package' && $runner test $split$files"
      fi
      package="${item%%|*}"
      files=
    fi
    file="${item#*|}"
    [ -n "$file" ] && files="$files $file"
  done
}

# `dartway check` over the two projects this repository hands out and shows:
# the skeleton `dartway create` copies, and the reference application agents
# read. Both are what a project's code is written after, so a convention they
# break is a convention every new project breaks — and nothing else runs the
# checker over them. Errors fail the gate; warnings and infos are printed and
# pass, as they do in a project.
#
# `migrationsDrift` needs a Postgres the analyze mode does not have: the check
# reports it as not checked and moves on. The migrations themselves are proved
# against a real database by `dartway test` in database.yml.
CHECKED_PROJECTS="template/dartway_starter_flutter example/dartway_example_flutter"

project_checks() {
  echo "══ dartway check"
  local contract_args=()
  if [ -n "${DW_CONTRACT_BASE:-}" ]; then
    local contract_sha
    contract_sha="$(git rev-parse --verify --end-of-options "${DW_CONTRACT_BASE}^{commit}")" || return 1
    contract_args=(--contract-base "$contract_sha")
    echo "Project contract baseline: $contract_sha (explicit trusted revision)"
  fi
  for project in $CHECKED_PROJECTS; do
    project_selected "$project" || continue
    spawn suite "dartway check: $project" \
      bash -c 'cd "$1" && dart run dartway_cli:dartway check "${@:2}"' _ "$project" \
        ${contract_args[@]+"${contract_args[@]}"}
  done
}

# Whether a project is checked: always when DW_CHECKS_ONLY is unset, when it
# names one of the project's packages — `template/dartway_starter_server` for
# `template/dartway_starter_flutter` — when it is set. The check reads the
# whole project.
project_selected() {
  [ -z "${DW_CHECKS_ONLY+set}" ] && return 0
  case " $DW_CHECKS_ONLY " in *" ${1%/*}/"*) return 0 ;; esac
  return 1
}

# The JavaScript half of the monorepo: each `js/*` package is its own npm
# project (no workspace, no shared `resolve`), checked by its own `npm run
# check` — typecheck, `node --test`, and the build that would ship to npm.
# There is exactly one today, `js/studio-bridge`; a second one under `js/`
# with a `package.json` is picked up the same way a new Dart package with a
# `pubspec.yaml` is by `packages()`.
js_packages() {
  find js -mindepth 2 -maxdepth 2 -name package.json \
    | sed 's|/package.json$||' | sort
}

# `node --test`'s own type stripping is what runs this repo's `.ts` test
# files at all — no build step in between. Below the version it became
# unflagged (22.18.0), the default file discovery silently matches nothing:
# `node --test` prints `# tests 0` and exits 0, which is indistinguishable
# from a suite that ran and passed. Read here from the package's own
# `engines.node` rather than repeated as a second constant, so the two cannot
# drift the way the pinned and floor Flutter versions are read from `.fvmrc`
# and each pubspec rather than written twice.
js_node_floor() {
  node -e "
    const pkg = JSON.parse(require('node:fs').readFileSync(process.argv[1], 'utf8'));
    process.stdout.write((pkg.engines && pkg.engines.node || '').replace(/^>=\s*/, ''));
  " "$1/package.json"
}

require_node_floor() {
  local package="$1"
  if ! command -v node >/dev/null 2>&1; then
    echo "js: node not found on PATH; $package needs it (see engines.node in its package.json)" >&2
    exit 1
  fi
  local floor have lowest
  floor="$(js_node_floor "$package")"
  [ -n "$floor" ] || return 0
  have="$(node --version)"; have="${have#v}"
  lowest="$(printf '%s\n%s\n' "$floor" "$have" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
  if [ "$lowest" != "$floor" ]; then
    echo "js: node $have is on PATH; $package is written against >= $floor" >&2
    echo "  (Node's unflagged .ts type stripping landed in 22.18.0 — node --test finds nothing below it, silently)" >&2
    exit 1
  fi
}

js_checks() {
  echo "══ js"
  # Few and short: the first part of a split run takes them.
  [ "$PART_INDEX" -eq 1 ] || return 0
  for package in $(js_packages); do
    selected "$package" || continue
    require_node_floor "$package"
    spawn js "$package (npm)" bash -c "cd '$package' && npm ci && npm run check"
  done
}

# `flutter test --platform chrome` finds the browser the way flutter_tools
# does: `CHROME_EXECUTABLE` when set, otherwise `google-chrome` on Linux and
# the application bundle on macOS. Checked first and refused by name, as
# `require_node_floor` refuses a missing Node: a browser lane that cannot start
# must not read as a lane with nothing to say.
require_chrome() {
  local package="$1" chrome
  if [ -n "${CHROME_EXECUTABLE:-}" ]; then
    chrome="$CHROME_EXECUTABLE"
  elif [ "$(uname)" = Darwin ]; then
    chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    chrome="google-chrome"
  fi
  if ! command -v "$chrome" >/dev/null 2>&1; then
    echo "browser: Chrome not found ($chrome); $package runs its suite in it" >&2
    echo "  install Chrome, or point CHROME_EXECUTABLE at a Chrome or Chromium binary" >&2
    exit 1
  fi
}

browser_suites() {
  echo "══ browser"
  [ "$PART_INDEX" -eq 1 ] || return 0
  for package in $(printf '%s\n' "$BROWSER" | cut -d'|' -f1); do
    selected "$package" || continue
    require_chrome "$package"
    spawn suite "$package (chrome)" \
      bash -c "cd '$package' && flutter test --platform chrome"
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
  local files
  for package in $(printf '%s\n' "$SERVICES" | cut -d'|' -f1); do
    touched "$package" || continue
    files=
    selected "$package" || files="$(selected_files "$package" | tr '\n' ' ')"
    spawn suite "$package ($(services_of "$package"))${files:+ ($files)}" \
      bash -c "cd '$package' && $(runner_of "$package") test $files"
  done
  # Side by side like the others: every suite here already shares the one
  # Postgres and storage with its own concurrent files, each under names of
  # its own.
  files="$(cli_service_files)"
  if [ -n "$files" ]; then
    spawn suite "packages/dartway_cli (external test servers)" \
      bash -c "cd packages/dartway_cli && dart test -t services --run-skipped $files"
  fi
  drain
}

# The CLI's files with suites against the services, those of them selected.
cli_service_files() {
  local file
  for file in test/test_external_servers_test.dart test/deploy_storage_visibility_test.dart; do
    if selected packages/dartway_cli || selected "packages/dartway_cli/$file"; then
      printf '%s ' "$file"
    fi
  done
}

# Nothing selected for this mode: say so and stop before resolving, and before
# asking for services nothing here would use.
if [ -n "${DW_CHECKS_ONLY+set}" ] && [ "$MODE" != all ]; then
  wanted=
  case "$MODE" in
    services)
      for package in $(printf '%s\n' "$SERVICES" | cut -d'|' -f1); do
        touched "$package" && wanted=1
      done
      [ -n "$(cli_service_files)" ] && wanted=1
      ;;
    test)
      for entry in $DW_CHECKS_ONLY; do
        { [ -f "$entry" ] || [ -f "$entry/package.json" ] || [ -d "$entry/test" ]; } && wanted=1
      done
      ;;
    analyze) [ -n "$DW_CHECKS_ONLY" ] && wanted=1 ;;
  esac
  if [ -z "$wanted" ]; then
    echo "✓ $MODE: nothing in DW_CHECKS_ONLY has anything to run here"
    exit 0
  fi
fi

[ "$MODE" = services ] && require_services
resolve
if [ "$MODE" = all ] || [ "$MODE" = analyze ]; then
  analyze
  project_checks
  drain
fi
if [ "$MODE" = all ] || [ "$MODE" = test ]; then
  test_suites
  js_checks
  drain
  # After the VM suites rather than beside them: a package's browser run and
  # its VM run would build in the same directory at once.
  browser_suites
  drain
fi
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
