---
title: The mini-player is sized by width and stays where it is released
affects:
  dartway_media_flutter: "0.2.0"
---

## Who is affected

A project that sets any of `miniPlayerInitialSize`, `miniPlayerMinScale` or `miniPlayerMaxScale`
in `DwMediaConfig` or `DwMediaOpenOptions` — they no longer exist; and a project that relies on
the mini-player snapping to a side, which is no longer the default.

## What to change

The size is a width now; the height follows the video's aspect ratio:

    - miniPlayerInitialSize: const Size(240, 135),
    + miniPlayerInitialWidth: 240,
    - miniPlayerMinScale: 0.75,
    - miniPlayerMaxScale: 2.0,
    + miniPlayerMinWidth: 180,           // pixels
    + miniPlayerMaxWidthFraction: 0.5,   // of the viewport width

To keep snapping to a side:

    + miniPlayerSnapToEdges: true,

A project that replaced `DwMiniPlayerHost` with a host of its own for free placement or a resize
handle can mount `DwMiniPlayerHost` again; its chrome draws the handle's mark at
`DwMiniPlayerHost.resizeCornerOf(context)` (see the example's `AppMiniPlayerChrome`).

## How to check

The project compiles; minimized, the player stays where it is dropped, and with a mouse connected
its corner opposite the screen's nearest one resizes it.
