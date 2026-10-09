---
title: StudioFrameController implementations add setInteractive
affects:
  dartway_studio_bridge: "0.11.0"
---

## Who is affected

A project with a class of its own that implements `StudioFrameController` — in practice a test
fake standing in for the preview frame. The interface gained `setInteractive(bool interactive)`,
and an implementation without it no longer compiles. A project that only calls
`createStudioFrameController` has nothing to change.

## What to change

Add the method to the implementation. A fake records the calls, or ignores them:

    class RecordingFrame implements StudioFrameController {
    + final interactive = <bool>[];
    +
    + @override
    + void setInteractive(bool interactive) => this.interactive.add(interactive);
      …
    }

A project that locks the preview frame by a page-wide rule — CSS setting `pointer-events: none` on
every iframe while an overlay is up — can lock this frame alone with
`controller.setInteractive(false)` and release it with `setInteractive(true)`.

## How to check

The project's analyzer reports no missing concrete implementation of
`StudioFrameController.setInteractive`, and its suites are green.
