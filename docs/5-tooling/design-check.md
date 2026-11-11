# Compare a Flutter screen with its Studio design

`dartway design-check` compares static Flutter widget-test states with the
Studio HTML committed for the agreed publication. It does not contact Studio
and deliberately does not compare transitions.

## Bind a screen

Put widget tests in `test/design_check/`. Import
`package:dartway_core_flutter/testing.dart`, pump the same static state for
each case requested by `DW_DESIGN_CHECK_CASES`, set the test view to the case's
width and height, then call:

```dart
await captureDwDesign(tester, caseId: 'profile-375x812');
```

The helper settles animations and records every visible render node's bounds,
text, fill, stroke, corner radius, shadow, and text style. Keep data, clocks,
images, and fonts deterministic just as for an ordinary golden test.

The published HTML declares design sizes and their Studio size class with one
meta element per size:

```html
<meta name="dw-viewport" content="expanded:1440x900">
<meta name="dw-viewport" content="medium:768x1024">
```

The command always adds a 375-pixel narrow capture, even when the HTML omits
one, so fixed-width overflow cannot disappear from the check.

This publication metadata is part of Studio's HTML contract: Studio must emit
`compact`, `medium`, or `expanded` when it publishes each screen. Until its
publisher is updated, the unclassified `WIDTHxHEIGHT` spelling remains valid,
but it cannot bind a size-class-specific state.

## Run locally and in CI

Name the publication commit and each bound HTML screen explicitly:

```sh
dartway design-check \
  --commit "$DESIGN_PUBLICATION_COMMIT" \
  --screen dw_studio/blocks/account/screens/profile.html
```

Chrome or Chromium 112 or newer is supported and found through `CHROME_EXECUTABLE` or `PATH`. The command materialises the publication commit in a temporary Git worktree so relative stylesheets, images, and fonts resolve, then captures each screen headlessly after
fonts, images, and animations settle. Screenshot and DOM capture use separate browser invocations for reliable headless output. It then runs all bound widget tests once and
writes `build/design-check/report.json`, `report.txt`, reference PNGs, and both
node specs. Commit the publication SHA to the CI configuration (or provide it
as a protected CI variable) and run the same command there.

The exit status is non-zero for a failed widget test, a missing capture, or an
unexplained difference. Two-pixel font-metric variation, sub-pixel stroke and
radius variation, and a translucent colour equivalent to its solid rendering
are ignored; overflow at a narrow width is never ignored.

To explain an intentional difference, pass `--acceptance path.json`. The file
is a JSON list whose entries contain the exact `case`, `node`, and `message`
from `report.json`, plus a non-empty `reason`. Accepted entries remain visible
under `accepted` in the machine-readable report but do not make the command
fail; stale or imprecise entries never suppress a new finding.
