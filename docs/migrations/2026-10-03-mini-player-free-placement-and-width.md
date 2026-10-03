---
title: The mini-player is sized by width and stays where it is released
affects:
  dartway_media_flutter: "0.2.0"
---

## Who is affected

A project that sets any of `miniPlayerInitialSize`, `miniPlayerMinScale` or `miniPlayerMaxScale`
in `DwMediaConfig` or `DwMediaOpenOptions` — they no longer exist; and a project that relies on
the mini-player snapping to a side, which is no longer the default. The default size changed too:
160 × 90 before, 240 wide now (the height from the video's ratio). And with a mouse connected, a
square in one corner of the player now belongs to the resize handle — it takes presses there, so
a button the project's chrome puts in that corner stops answering clicks.

## What to change

The size is a width now; the height follows the video's aspect ratio:

    - miniPlayerInitialSize: const Size(240, 135),
    + miniPlayerInitialWidth: 240,
    - miniPlayerMinScale: 0.75,
    - miniPlayerMaxScale: 2.0,
    + miniPlayerMinWidth: 120,           // pixels
    + miniPlayerMaxWidthFraction: 0.5,   // of the viewport width

To keep snapping to a side:

    + miniPlayerSnapToEdges: true,

To keep the old 160 × 90 look:

    + miniPlayerInitialWidth: 160,

To keep the chrome's corner buttons clickable, move them off the handle's corner — read it in the
chrome and place the buttons on the other side:

    + final handle = DwMiniPlayerHost.resizeCornerOf(context); // null: no handle
    + final close = handle == Alignment.topRight ? Alignment.topLeft : Alignment.topRight;

or turn the handle off: `miniPlayerResize: DwMiniPlayerResize.never` (no resizing at all).

A project that replaced `DwMiniPlayerHost` with a host of its own for free placement or a resize
handle can mount `DwMiniPlayerHost` again; its chrome draws the handle's mark at
`DwMiniPlayerHost.resizeCornerOf(context)` (see the example's `AppMiniPlayerChrome`).

## How to check

With a mouse connected, every button of the chrome answers a click; the project compiles; minimized, the player stays where it is dropped, and with a mouse connected
its corner opposite the screen's nearest one resizes it.
