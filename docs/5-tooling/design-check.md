# Compare a Flutter screen with its Studio design

`dartway design-check` compares static Flutter widget-test states with the
Studio HTML committed for the agreed publication. It does not contact Studio
and deliberately does not compare transitions.

## Bind a screen

Put widget tests in `test/design_check/`. Import
`package:dartway_core_flutter/testing.dart` and loop over
`dwDesignCheckCases`. The command supplies the complete case id and logical
view size, so the test does not reconstruct either from the repository path:

```dart
for (final captureCase in dwDesignCheckCases) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(captureCase.width, captureCase.height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
  await captureDwDesign(tester, caseId: captureCase.id);
}
```

The helper settles animations and records every visible render node's bounds,
text, fill, stroke, corner radius, shadow, and text style. Outside a
`dartway design-check` run it returns `null` without settling or capturing, so
these tests remain safe in an ordinary `flutter test` run. Keep data, clocks,
and images deterministic. Declare the design's real font files under `fonts:`
in the Flutter package's `pubspec.yaml`; the capture helper loads that manifest
before it settles the screen. Do not use the Flutter test font for a design
check: its metrics do not match the browser font even when `TextStyle` reports
the browser family's name.

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
node specs. Comparisons whose capture files exist still run when another widget
test fails, and the report also records that test failure. Commit the publication SHA to the CI configuration (or provide it
as a protected CI variable) and run the same command there. The checkout must
fetch that commit: a shallow checkout that does not contain it cannot create
the comparison worktree.

For GitHub Actions, install Chrome and fetch history before running from the
project root (or from its Flutter package):

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- uses: browser-actions/setup-chrome@v1
- name: Check published designs
  working-directory: .
  env:
    DESIGN_PUBLICATION_COMMIT: ${{ vars.DESIGN_PUBLICATION_COMMIT }}
  run: >-
    dartway design-check
    --commit "$DESIGN_PUBLICATION_COMMIT"
    --screen dw_studio/blocks/account/screens/profile.html
```

Relative `--tests`, `--output`, and `--acceptance` paths are resolved in the
Flutter package even when the command starts at the project root. The exit
status is non-zero for a failed widget test, a missing capture, or an
unexplained difference. Two-pixel line-height and box-metric variation, sub-pixel stroke and
radius variation, and a translucent colour equivalent to its solid rendering
are ignored; overflow at a narrow width is never ignored.

To explain an intentional difference, pass `--acceptance path.json`. The file
is a JSON list whose entries contain the exact `case`, `node`, and `message`
from `report.json`, plus a non-empty `reason`. Accepted entries remain visible
under `accepted` in the machine-readable report but do not make the command
fail; stale or imprecise entries never suppress a new finding.
