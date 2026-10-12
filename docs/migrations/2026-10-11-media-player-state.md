---
title: Media controls follow intent and the package confirms played spans
affects:
  dartway_media_flutter: "0.3.0-dev.0"
---

## Who is affected

Projects using `dartway_media_flutter`, especially copied media chrome or manual played-span observers.

## What to change

- Remove `session.playbackObservation`, `DwMediaObservationHandle`,
  `DwMediaObservationResult`, and manual `record`/confirmation adapters. Keep
  `playbackDelivery`: the package now supplies played spans automatically and seals
  them on pause, seek, speed change, source change, error, end and disposal.
  Remove any position-gap heuristics to avoid counting the same playback twice.
- Replace `DwMediaPlayState.buffering` and `isBuffering` with `status.waiting` for
  a spinner. Draw play/pause from `status.intent == DwMediaPlayIntent.play` and
  call `session.togglePlay()`; waiting must not change the button or controls timer.
- Listen to `session.status` for controls and `session.position` for the timeline.
  `session.playback` remains their merged state. Draw a timeline thumb from its
  active drag, then `seekTarget`, then the playback position; call `seek` before
  clearing the drag on release.
- Replace application flags for whether the current item really played with
  `session.hasReallyPlayed`. Playback intent survives a source retry; pause first
  if the retry should remain paused.

Copy the updated chrome from the framework repository's
`example/dartway_example_flutter/lib/ui_kit/3_special/media/` as needed.

## How to check

With fake engines, buffer while playing: pause remains available and waiting only
shows a spinner. Hold a seek, release the timeline and skip twice: no old position
is drawn and two +10 commands land at +20. Check delivered intervals exclude the
seek gap; retain the existing pending-report inspection and retry handling.
