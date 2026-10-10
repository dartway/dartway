---
title: CI holds the committed dependency locks
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

A project whose `.github/workflows/ci.yml` runs any `pub get` without
`--enforce-lockfile`, including projects created before
[#495](https://github.com/dartway/dartway/pull/495).

The deploy images build with the committed locks. CI that resolves dependencies without holding
those locks lets a stale `pubspec.lock` pass the pull request and fail the deploy image build.

## What to change

Add `--enforce-lockfile` to every `pub get` in the project's `.github/workflows/ci.yml`:
`dart pub get` for the shared and server packages, and `flutter pub get` for the Flutter package.
The `pub get` step in the framework's
[template workflow](../../template/.github/workflows/ci.yml) is the reference:

```yaml
- name: pub get
  id: deps
  run: |
    (cd dartway_starter_shared && dart pub get --enforce-lockfile)
    (cd dartway_starter_server && dart pub get --enforce-lockfile)
    (cd dartway_starter_flutter && flutter pub get --enforce-lockfile)
```

Replace the template's package directory names with the project's own names.

**Before committing the change**, run `dart pub get` without the flag once in each of the shared
and server packages, and `flutter pub get` without the flag once in the Flutter package. Commit
any `pubspec.lock` that moves together with the workflow change. Otherwise the first CI run can
fail on a stale lock already in the project's default branch.

A project with no `ci.yml` adopts the template's whole file; follow the template README's
[Continuous integration section](../../template/README.md#continuous-integration).

## How to check

From the project root:

```sh
grep -c -- '--enforce-lockfile' .github/workflows/ci.yml
```

The count is one per package: `3` for the shared, server and Flutter packages. Check that every
`pub get` carries the flag, then run the project's CI and confirm its dependency step passes
with the committed locks.
