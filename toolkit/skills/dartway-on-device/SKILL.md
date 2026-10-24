---
name: dartway-on-device
description: "Diagnose phone keyboard, focus, scrolling and viewport differences on native iOS and iOS web."
---

# DartWay — keyboard, focus and viewport on phones (`dartway-on-device`)

These entries cover phone behaviour that desktop testing can miss, with known mechanisms and
workarounds. Some also reproduce in the iOS simulator or a widget test; those do not replace checking
the actual keyboard and browser on a device. Whether an automatable case needs a test follows the risk
classes and gate of `dartway-testing` §4. A staging build is usually shown on a phone browser: if a
change touches a field, a sheet or the web shell, open it on a phone once.

## Follow native iOS keyboard frames; smooth inset steps elsewhere

**Native iOS:** modern Flutter already animates `MediaQuery.viewInsets` frame by frame. The engine's
[`KeyboardInsetManager`](https://chromium.googlesource.com/external/github.com/flutter/flutter/+/69cf0c00f4c6607218c3fd66c036e75476f17a8c/engine/src/flutter/shell/platform/darwin/ios/framework/Source/KeyboardInsetManager.swift)
follows the keyboard's native animation on each display-link tick. Read those insets directly, with no
app-side tween. A second animation makes content lag behind the keyboard and leaves a visible tail
after it stops, especially in a bottom sheet. This can also be reproduced in the iOS simulator.

**Web, including iOS WebKit, and other platforms:** insets can arrive in steps while the keyboard is
still travelling, so layout computed directly from them can snap ahead. Keep the skeleton's 250 ms
ease-out tween here; it is a fallback for step changes, not a universal keyboard duration.

**One helper for both:** the skeleton's `AppKeyboardInset` (`lib/ui_kit/utils/`) passes the raw inset
through when `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`, and tweens it otherwise.
Keep the web guard: an iPhone browser is web, not native iOS. Older copies of the helper that tween
unconditionally need the same platform split. Everything keyboard-dependent reads its builder value:

```dart
AppKeyboardInset(
  builder: (_, keyboardInset) => Padding(
    padding: EdgeInsets.only(bottom: AppSpace.s16 + keyboardInset),
    child: child,
  ),
)
```

**All of it** — height, padding, edges — uses this one value so the parts move together. Check raw
`viewInsets` reads outside `app_keyboard_inset.dart` for a surface mixing two inset sources. In a widget
test, feed successive inset frames on native iOS and assert each is delivered immediately with no
250 ms tail; test step interpolation separately on web and other platforms. Device testing still
checks whether the actual keyboard and the surface move together.
During dismissal, the quick sheet freezes its geometry so keyboard resizing cannot fight the
slide-out. Navigation reads the raw inset only to detect coverage; its bottom position stays anchored
to `viewPadding`.

## WebKit raises the keyboard only for a focus inside the gesture

**Symptom:** on iOS web a sheet opens with a caret in its field and no keyboard. **Mechanism:** the
keyboard comes only for a `focus()` made synchronously in a user gesture, and the sheet's field does not
exist yet at the tap — `autofocus` or a post-frame `requestFocus` is too late. **Workaround — a primer
field:** an always-mounted invisible `EditableText` (not `TextField`: no `Material` above it) bound to an
scaffold-owned `FocusNode`, beside the page shell, in `Opacity(opacity: 0)`, `ExcludeSemantics` and
`IgnorePointer`. The open-the-sheet handler calls `focusNode.requestFocus()` synchronously in the tap,
then opens the sheet; the real field takes focus next frame and the keyboard stays up. Keep the primer
inside the viewport at 1 px so Safari does not scroll toward an off-screen field. Native opening does
not use the primer: the template's quick overlay calls `onInputReady` 150 ms into its 250 ms entrance
so the platform has time to start the keyboard. `AppScaffold.main(quickEntry: ...)` wires both paths.

## The web shell must pin the document

**Symptom:** on an iPhone (Safari and Chrome alike) focusing a field scrolls the app off screen, leaving
a blank backdrop; nothing is logged. **Mechanism:** the engine restores its hidden input at a position
computed before the keyboard, and WebKit scrolls the document to it, taking the one-viewport canvas along.
**Workaround:** the skeleton's `web/index.html` carries `viewport-scroll-lock-style` / `-script` —
`html { overflow: hidden }`, a fixed `body` with `overscroll-behavior: none`, and a `focusin` listener
resetting the scroll immediately, next frame, at 150 and 400 ms, plus `visualViewport` events.
`web/index.html` is part of the app: anything that regenerates it (`flutter create .`, a splash tool)
drops the block silently. Check: `grep -q 'focusin' web/index.html`.
