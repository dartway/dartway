---
title: Follow native iOS keyboard insets without a second tween
affects:
  dartway_cli: "0.25.0"
---

## Who is affected

Projects whose copied `lib/ui_kit/utils/app_keyboard_inset.dart` always tweens
`MediaQuery.viewInsets`, including native iOS builds.

## What to change

Import `package:flutter/foundation.dart` in `lib/ui_kit/ui_kit.dart`. In
`AppKeyboardInset.build`, read the inset once and return the builder directly
on native iOS, before the existing `TweenAnimationBuilder`:

```dart
final inset = MediaQuery.viewInsetsOf(context).bottom;
if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
  return builder(context, inset);
}
```

Use `inset` as the tween's end value on the remaining path. Keep that 250 ms
ease-out tween on web (including iOS browsers) and other platforms. Compute
every keyboard-dependent height, padding and edge from the helper's builder
value. Native iOS already supplies animated engine insets; a second tween
adds lag and an animation tail.

## How to check

In a native iOS widget test, feed changing insets at frame intervals through
the helper. Each builder value must equal the supplied inset immediately,
including during closing or reversal, and no animation should remain after
the final frame. Keep a separate test that step changes still interpolate
on web and other platforms. Open and dismiss a sheet with a field on iOS:
its geometry should follow the keyboard without a trailing wave.
