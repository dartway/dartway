---
name: dartway-on-device
description: >-
  What only a real phone shows: keyboard, focus, scroll and viewport behaviour on iOS and iOS web
  that is invisible in the simulator, a desktop browser and a widget test — each with its mechanism
  and the known workaround. Use for "the keyboard does not come up", "the screen jumped or went blank
  when I tapped the field", "it blinks and reopens", "works in the simulator, not on my phone" — and
  before writing anything that focuses a field, opens a sheet over the keyboard, or will be opened
  from a phone browser.
---

# DartWay — what only the device tells you (`dartway-on-device`)

An entry here reproduces on a real device, is invisible in the iOS simulator, a desktop browser and a
widget test, and has a known workaround. Anything a test can assert belongs in a test instead. A staging
build is usually shown on a phone browser: if a change touches a field, a sheet or the web shell, open it
on a phone once.

## The keyboard is a step, iOS says so, and it travels for 250 ms

**Symptom:** a sheet with a field snaps to its final geometry while the keyboard is still moving — "it
blinked and reopened". **Mechanism:** `MediaQuery.viewInsets` changes in steps (two on iOS: the accessory
bar, then the keyboard). **Workaround:** everything keyboard-dependent reads the skeleton's
`AppKeyboardInset` (`lib/ui_kit/utils/`), a tween over the raw inset with the keyboard's duration and
curve:

```dart
AppKeyboardInset(
  builder: (_, keyboardInset) => Padding(
    padding: EdgeInsets.only(bottom: AppSpace.s16 + keyboardInset),
    child: child,
  ),
)
```

**All of it** — height, padding, edges; half on the raw inset slides apart from the other half. Check:
`grep -rn 'viewInsetsOf' lib/ui_kit` — any hit outside the smoother is one.

## WebKit raises the keyboard only for a focus inside the gesture

**Symptom:** on iOS web a sheet opens with a caret in its field and no keyboard. **Mechanism:** the
keyboard comes only for a `focus()` made synchronously in a user gesture, and the sheet's field does not
exist yet at the tap — `autofocus` or a post-frame `requestFocus` is too late. **Workaround — a primer
field:** an always-mounted invisible `EditableText` (not `TextField`: no `Material` above it) bound to an
app-level `FocusNode` provider, beside the page shell, in `Opacity(opacity: 0)`, `ExcludeSemantics` and
`IgnorePointer`. The open-the-sheet handler calls `focusNode.requestFocus()` synchronously in the tap,
then opens the sheet; the real field takes focus next frame and the keyboard stays up. One code path on
every platform. Check by reading: a `requestFocus` in an `addPostFrameCallback` reached by a tap.

## The web shell must pin the document

**Symptom:** on an iPhone (Safari and Chrome alike) focusing a field scrolls the app off screen, leaving
a blank backdrop; nothing is logged. **Mechanism:** the engine restores its hidden input at a position
computed before the keyboard, and WebKit scrolls the document to it, taking the one-viewport canvas along.
**Workaround:** the skeleton's `web/index.html` carries `viewport-scroll-lock-style` / `-script` —
`html { overflow: hidden }`, a fixed `body` with `overscroll-behavior: none`, and a `focusin` listener
resetting the scroll immediately, next frame, at 150 and 400 ms, plus `visualViewport` events.
`web/index.html` is part of the app: anything that regenerates it (`flutter create .`, a splash tool)
drops the block silently. Check: `grep -q 'focusin' web/index.html`.
