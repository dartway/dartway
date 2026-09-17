---
title: "DwErrorReport.actionLabel is now label, and handleError takes it for any source"
affects:
  dartway_core_flutter: "0.20.0-dev.1"
---

## Who is affected

A project that reads `DwErrorReport.actionLabel` in its error policy or report sink, or passes
`actionLabel:` to `dw.handleError`. Studio, Molodey and U90 do neither; their own widgets'
`actionLabel` parameters are theirs and unaffected.

## What changed

The report's one free-text label was named after `DwUiAction`, so a caller reporting anything else
did not see it as theirs to fill (#126). It is `label` now, documented for every source; a
`DwUiAction` fills it as before (its `label`, else its error, else its success notification).

## What to change

```dart
report.label                                   // was: report.actionLabel
dw.handleError(e, st, label: 'Sync contacts')  // was: actionLabel:
```
