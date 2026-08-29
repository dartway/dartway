---
name: dartway-on-device
description: >-
  What only a real phone will tell you: platform behaviour that is invisible in the iOS simulator,
  in a desktop browser and in a widget test, and shows up for the first time on a device — usually
  the device you are showing a staging build on. Keyboard, focus, scroll and viewport behaviour on
  iOS and iOS web, with the mechanism and the known workaround for each. Use when someone reports
  "the keyboard does not come up", "the screen jumped / went blank when I tapped the field", "it
  blinks and reopens", "it works in the simulator but not on my phone", "it works on desktop but not
  on mobile" — and before writing anything that focuses a field, opens a sheet over the keyboard, or
  is going to be opened from a phone browser.
---

# DartWay — what only the device tells you (`dartway-on-device`)

Every entry here cost somebody a search in the wrong place. Not because the bug was subtle, but
because **the environment that reproduces it is not the environment anybody develops in**: the iOS
simulator raises keyboards fine, a desktop browser has no keyboard to raise, and a widget test has
neither a browser nor a phone. The code looks right, the tests are green, and the report says "it
does not work on my phone".

So this skill is not a topic. It is a **provenance**: things the framework cannot tell you and the
emulator will not show you.

## What belongs here, and what does not

An entry is admitted only if all three hold:

1. it **reproduces on a real device**;
2. it is **invisible** in the iOS simulator, in a desktop browser and in a widget test;
3. it has a **known workaround**, written down.

Anything visible in a test belongs in a test, not here — a rule you can assert is worth more than a
rule you can read. Anything that is a matter of taste belongs in the design system
(`dartway-ui-kit`). Anything about the structure of a feature belongs in `dartway-feature-scaffold`.
Without this rule the file becomes the place things go when nobody wants to decide, and then nobody
reads it.

**Where the mechanism lives is here; where the law lives may be elsewhere.** The web shell being part
of the application is a structural rule and it stays in the project's `CLAUDE.md`. Why iOS makes it
necessary is here.

---

## The keyboard is not an instant, and iOS says it is

**Symptom.** A bottom sheet with a text field snaps into its final geometry while the keyboard is
still moving. It reads as "it blinked and reopened".

**Mechanism.** The system reports the keyboard as a **step change** in `MediaQuery.viewInsets` — on
iOS as two steps, first for the accessory bar above the keyboard and then for the keyboard itself —
while the keyboard actually travels for about 250 ms. Layout computed straight from the raw inset is
therefore correct and early, which looks like a glitch.

**Workaround.** A smoother the whole layout reads through — the skeleton ships `AppKeyboardInset` in
`lib/ui_kit/utils/`, a `TweenAnimationBuilder` over `MediaQuery.viewInsetsOf(context).bottom` with
the keyboard's own duration and curve:

```dart
AppKeyboardInset(
  builder: (_, keyboardInset) => Padding(
    padding: EdgeInsets.only(bottom: 16 + keyboardInset),
    child: child,
  ),
)
```

**The discipline is the part that matters.** Compute *everything* keyboard-dependent from the
smoothed value — height, bottom padding, edges. Converting the padding and leaving the height on the
raw inset is **worse than doing nothing**: the two halves visibly slide apart. It does not look like
a violation on the page either — a raw `viewInsets` in layout is exactly what the Flutter
documentation suggests — so the check is a grep:

```bash
grep -rn 'viewInsetsOf' lib/ui_kit    # any hit outside the smoother itself is one
```

Nothing animates on the first build: with no `begin` the tween starts at its end, so a sheet opened
over an already-raised keyboard is in place rather than sliding into it.

---

## WebKit shows the keyboard only for a focus inside the gesture

**Symptom.** On iOS web, a sheet opens with a text field, the field shows a caret — and no keyboard.
The user taps the field a second time to get one.

**Mechanism.** WebKit's rule: the keyboard is raised only by a `focus()` that happens
**synchronously inside a user gesture**. At the moment of the tap the field does not exist yet — the
sheet is built on the next frame, so its own focus request is post-frame, and the browser does not
count that as a user action.

**Writing it the broken way is what any documentation will suggest.** `autofocus`, or a
`requestFocus` in `initState` or an `addPostFrameCallback`, is the natural answer to "the field is
not mounted yet", and it is correct on every platform except this one.

**Workaround — a primer field.** An always-mounted invisible input takes the focus *inside* the
gesture, and hands it to the real field a frame later. Moving focus between fields while the
keyboard is already up needs no gesture, so it simply stays up.

- an app-level `FocusNode` provider, and an invisible `EditableText` bound to it, mounted once beside
  the page shell;
- **`EditableText`, not `TextField`** — the primer sits above `Scaffold`, where there is no
  `Material` ancestor, and it needs `Material` only for drawing, which it never does;
- **`Opacity(opacity: 0)`, not transparent colours** — whatever is typed during the single frame the
  primer still holds focus would otherwise paint over the bottom bar;
- wrapped in `ExcludeSemantics` + `IgnorePointer`;
- the open-the-sheet handler calls `focusNode.requestFocus()` **synchronously in the tap**, then
  opens the sheet; the real field takes focus on the next frame.

It runs on every platform, and only WebKit has the gesture rule — elsewhere the keyboard would have
come up anyway, one frame later. Keeping a second branch for that means keeping a half nothing
exercises.

**The check is a reading, not a grep:** a `requestFocus` inside an `addPostFrameCallback` in code
reached by a tap.

---

## The web shell has to pin the document, or the first field takes the app off screen

**Symptom.** On an iPhone — Safari and Chrome alike, one engine — focusing a text field scrolls the
app off the screen. What is left is a blank backdrop. It does not happen a second time, because the
document is already scrolled.

**Mechanism.** The engine parks its own DOM input off screen and restores it ~100 ms later, at a
position computed *before* the layout knew about the keyboard — underneath it. WebKit then does what
it always does and scrolls the page to bring that position into view. The Flutter canvas is exactly
one layout viewport tall, so it travels up with the document. Nothing fails and nothing is logged:
from Dart the widget tree is intact, the sheet is built, the field has focus — so the search goes to
the sheet's own markup, where the bug is not.

**Workaround.** Give the document nothing to scroll, and return any residual scroll to zero across
the whole travel rather than at one moment of it. The skeleton ships this in
`web/index.html` as `viewport-scroll-lock-style` / `-script`: `html { overflow: hidden }`, a `body`
fixed to the four edges with `overscroll-behavior: none`, and a `focusin` listener that pins the
scroll immediately, on the next frame, at 150 ms and at 400 ms, plus the `visualViewport` events.

It costs the app nothing — Flutter on web scrolls its own content and keeps the document exactly one
window tall.

**Anything that regenerates the shell drops the block silently** — `flutter create .`, a
splash-screen tool. The check:

```bash
grep -q 'focusin' web/index.html
```

---

## Before you show a build to anyone

All three of these are met by the person you are showing a staging build to, because **a phone
browser is how a staging build gets shown**. None of them is met by you, on the machine where you
wrote it. If a change touches a field, a sheet or the shell, open it on a phone once — that is the
whole test, and it is the only environment that runs it.
