---
name: dartway-ui-kit
description: >-
  UI Kit rules in DartWay Flutter: the kit lives as SOURCE inside the app (lib/ui_kit/) — the framework
  ships neither buttons, nor text, nor a theme. AppText/AppButton are app widgets with named
  constructors, AppTextStyle is a token for places where Flutter demands a TextStyle; the theme
  (AppTheme) is in the kit too. DwActionBuilder from the framework guards the action (busy, double tap,
  form validation). Inside features Color/TextStyle/BorderRadius/Theme.of/context.textTheme/colorScheme
  are forbidden; the only import is ui_kit.dart; part-of structure. Use when creating/editing UI
  components, styles, colors, themes, buttons, or when adding widgets to the kit.
---

# DartWay — UI Kit

**The kit belongs to the app.** It lives as source in `__FLUTTER_PKG__/lib/ui_kit/`, `dartway create`
puts it there, and from then on the project edits it freely — it is its code, not a dependency.

**The framework ships no design.** `dartway_flutter` has **no** `DwButton`, `DwText`,
`DwFlutterTheme`, `DwColorPreset`, and no style presets. Don't look for them and don't import them —
they do not exist. There is no `dartway_ui_kit` package either, and there won't be: otherwise the app
would end up with two kits — ours in dependencies and its own in `lib/` — and every `AppButton` would
raise the question "whose is this".

The framework gives exactly what the app should not reinvent: **`DwActionBuilder`**
(action mechanics) and **`dwBuildAsync`** (a single render of loading/error/data).

**Naming convention.** `Dw*` — framework: comes from outside, gets updated, don't edit. The kit is app
code, it has no `Dw` prefix: `App*` where it would otherwise collide with Flutter (`AppText`,
`AppButton`), and no prefix where there is no collision (`ConditionalParent`, `MultiLinkText`,
`DeviceFrameShell`). One look at an identifier tells you whether it is yours or the framework's.

## Core principles

1. **One import.** Components are imported only through the root `ui_kit.dart`. Never import
   individual buttons/colors/styles directly.
2. **Everything is declared in `ui_kit.dart`.** Every component file starts with `part of '../ui_kit.dart';`.
   The root file assembles everything with `part` directives and re-exports `dartway_flutter`.
3. **No raw styling in features.** Inside a zone (`app/`, `admin/`, `auth/`, `common/`) and in `shared/`
   the following are **forbidden**: `Color`, `TextStyle`, `BorderRadius`, `Colors.*`, `Theme.of(context)`,
   `context.theme`, `context.textTheme`, `context.colorScheme`. This is not a wish — the
   `forbidden_ui_style_usage` rule from `dartway_lints` (via `custom_lint`) allows them **only inside
   `ui_kit/`** and recognizes `BuildContext` by type, not by variable name.

   **What to do when Flutter demands a style, not a widget** (`Icon(color:)`,
   `InputDecoration.labelStyle`, `TextSpan`, a third-party widget with `style:`): such a widget
   **moves into the kit whole**, and the feature composes it. Inside the kit the style is taken from a
   token (`AppTextStyle.body.resolve(context)`). Working around the rule with `// ignore:` is a style
   that escaped the kit; the next screen will never learn about it.

   **And inside the kit a colour comes from the context too.** The rule above says where styling may
   live and nothing about how a kit widget obtains a colour — so a `static const Color` looks
   permitted, and it is the token that will not survive a second theme: a const does not depend on a
   context, so changing `ThemeData` does not touch it. Nothing diagnoses it — the analyzer is quiet,
   the tests are green — and it surfaces on the day somebody asks for a light theme, as a rewrite of
   every read in the kit at once. Take colours and text styles from the palette
   (`context.colorScheme`, a `resolve(context)` token); `dartway check` warns on a `static const
   Color`/`TextStyle` under `lib/ui_kit/` (`uiKitConstStyle`). **`ui_kit/theme/` is exempt** — that is
   where the theme is assembled and a seed colour has to live somewhere. Geometry stays `const`: a
   radius does not depend on the theme. One theme in a project means a palette with one set of
   colours, not the absence of `of(context)`.
4. **Isolated visual layer.** The kit does not depend on business logic or state. A component =
   pure visuals + minimal props.
5. **The kit is the app's design system, not a library of shared widgets.** A composite needed by a
   single feature (an event card, a card feed, a section header) is also the kit: the `3_special/` zone
   exists for exactly this. What stays in the feature is **mapping the domain** to the kit's parameters,
   not layout.

6. **The public API of a kit widget takes no visual types.** No `Color`, `TextStyle`,
   `EdgeInsets`, `BorderRadius`, `BoxDecoration` in the constructor — the look is chosen by **named
   constructors**, and only data, state and callbacks go outward.

   This is the twin rule to point 3, and without it point 3 is bypassed **by construction**: `AppColors.x`
   is a legal symbol, so as long as the kit accepts a color, the feature is obliged to know it. That is
   exactly what happened on a production project: 40 kit widgets with color fields, 268 palette lookups
   from features, and 48 tokens out of 131 named after somebody else's feature — an event badge was
   painted with `settingsNavigationRowLeadingFill` and `chatSendIconActive`.

   **Review signal:** you see in a feature a token named after another feature — what's needed is a kit
   constructor, not picking a color by visual resemblance.

7. **A feature assembles a surface by hand only when the kit doesn't have it.** Before fixing such a
   place, look at the kit primitive: most likely it **doesn't cover the needed variant**, and it is the
   primitive that must be rewritten, not twenty call sites.

   How it looks in real life: `AppContainer` could do a fill but **could not do a border** — while
   accepting `fillColor` and `borderRadius` from outside. Simultaneously too weak (the needed case is
   missing) and too open (it lets a color through). The result — ten nearly identical
   `Container(decoration: BoxDecoration(...))` across features: a badge, a category card, a preview, a
   post body, a dialog, a popup. It is fixed by one edit of the primitive:

   ```dart
   // ❌ a primitive that forces the feature to know the color and the radius
   const AppContainer.surface({required this.child, this.fillColor, this.borderRadius});

   // ✅ the constructor picks the look, the tone is a semantic enum; padding stays (that's screen layout)
   const AppContainer.surface({required this.child, this.padding, this.onTap});
   const AppContainer.tinted({required this.child, required this.tone, ...});
   const AppContainer.outlined({required this.child, ...});
   const AppContainer.dialogCard({required this.child, ...});

   enum AppSurfaceTone { plain, muted, control, achieved }
   ```

   **Rule for migrating without changing the visuals:** walk through every call site that passed a
   visual parameter and check the value. Some pass exactly the default — the parameter is simply
   removed. Some pass their own — they need a constructor or a tone **with the same token**. Not a
   single color and not a single radius may change value; then "we reworked the primitive" doesn't turn
   into "the design drifted".

   **Distinguish what belongs to the kit at all.** `padding` outward is fine: how much air there is
   inside a block is the screen's call. Color, radius, shadow, border — no.

## Assets — an enum dictionary plus one renderer, no generator

Two files in the kit, and that's it:

```dart
// ui_kit/assets/app_icon.dart — the dictionary: what can be shown at all
enum AppIcon {
  authRobot('assets/icons/auth/robot.svg'),
  lessonLock('assets/icons/lessons/lock.png');

  const AppIcon(this.path);
  final String path;
  bool get isVector => path.endsWith('.svg');
}

// ui_kit/assets/app_icon_view.dart — the only place that calls Image.asset/SvgPicture.asset
class AppIconView extends StatelessWidget {
  const AppIconView(this.icon, {super.key, this.size});
  ...
}
```

A feature writes `AppIconView(AppIcon.authRobot, size: 24)` — it **names the meaning, not the file**.

**Why this way and not a constructor per asset:** the parameters live in one place. Adding
`semanticsLabel` is an edit in one widget, not in seventy constructors. And both formats are resolved
**inside**, by extension: replacing a PNG with an SVG is a one-line edit in the dictionary, the screens
are not touched at all.

**One `size`, not `width` and `height`.** An icon keeps its proportions; separate width and height
almost always mean the wrong asset was taken, not a deliberate stretch. Something that must fill an
area by width with `fit` is **not an icon but a cover**: it has its own widget and its own parameters.

- **a raw path in a feature is forbidden** — `Image.asset('assets/…')` in a screen means the image
  cannot be found by search and will survive a file rename only by accident;
- `flutter_gen` is not needed: that a path leads to an existing file is checked by `dartway check` — and
  the same checker catches raw paths, which the generator never could;
- **fonts** never reach the code: they are declared in the pubspec and arrive through text styles. Sounds
  and video are not widgets, their place is in the data layer next to the player, not in the kit.

## Named constructor or parameter

Both express meaning, not decoration — the question is who chooses.

- **Named constructor** — when the choice is static at the call site: `AppEventCard.compact` in a feed,
  `.wide` in a list. The caller always knows which one it needs.
- **Semantic parameter** — when the caller has a runtime value: `AppButton.filterChip(selected: isActive)`,
  `AppBottomSheetPageBody(fillsScreen: isFullScreen)`. Forcing a constructor choice here means getting a
  ten-line ternary in the feature — that is, the same composition, just sideways.

A parameter is named by meaning (`selected`, `fillsScreen`), not by look (`isDark`, `withShadow`),
and if it changes several things at once, that is written in its doc: why one flag and not three.

## Composing a recognizable unit — in the kit

A card, a card feed, a section header with an "all" link, a screen surface — these are units, not
one-off layout. Their geometry, paddings, corner radii and background belong to the kit entirely; the
feature passes data and callbacks.

Two consequences that are easy to get wrong:

- **System insets (safe area) — inside the kit widget.** A surface glued to the bottom must respect the
  bottom inset by definition. As long as the caller computes it, every next screen repeats the same
  arithmetic, and one day it will forget it.
- **Sizes are published by the kit, not by the feature.** The card height a feed needs is a kit constant
  (`AppEventCard.compactHeight`), not a public field of the feature. A feature may read the size, but not assign it.

## The kit does not know the domain

The kit does not import app models and does not switch on domain enums. If a widget picks an image based
on the reason a course is locked, and that enum carries user-facing texts inside — **a widget with two
constructors moves into the kit**, and the domain `switch` stays in the feature as a single line. Moving
the enum itself into the kit is not allowed: the texts would come with it, and text constants have no
place in the kit.

## Text: a widget with named constructors + a token enum

Two different entities, and they must not be collapsed into one:

- **`AppText`** — a widget with `const` constructors. This is what you write in 99% of places.
- **`AppTextStyle`** — a token. It is needed where Flutter demands exactly a `TextStyle`, not a widget
  (`InputDecoration.labelStyle`, `TextSpan`, `Icon`, third-party widgets with `style:`).

```dart
const AppText.title('DartWay.dev')          // const works — and enclosing consts too
AppText.body(post.description)
AppText.caption('${date.dayLabel} · ${date.timeLabel}')
```

**All user-facing text comes from l10n, not from a string literal.** Every DartWay project is localized — a requirement, not a description of how the project started, and if the wiring is missing it is fixed before the strings pile up (see the localization law and its migration entry in `CLAUDE.md`). `AppText.body('Book a spot')` with a hardcoded string desyncs the feature from the rest of the app. Take the text from `context.l10n`:

```dart
final l10n = context.l10n;
AppText.body(l10n.bookSpot)
```

A new string = add a key to **every** ARB the project keeps (the skeleton ships `lib/l10n/app_en.arb` and `app_ru.arb`), run `flutter gen-l10n`, and **commit its output** — `lib/l10n/gen/` belongs in the repository for the same reason the generated protocol does. `gen-l10n` is a separate CLI, not `build_runner`: it runs when an `.arb` changes, not on every save. Only non-text stays a literal in the UI (icons, debug labels behind `kDebugMode`).

```dart
// ui_kit/theme/app_text.dart
enum AppTextStyle {
  title, body, link, caption;

  TextStyle resolve(BuildContext context) => switch (this) {
    AppTextStyle.title => (context.textTheme.titleLarge ?? const TextStyle(fontSize: 20))
        .copyWith(color: context.colorScheme.onSurface),
    // ...
  };
}

class AppText extends StatelessWidget {
  const AppText.title(this.text, {super.key, this.textAlign, this.maxLines})
      : style = AppTextStyle.title;
  const AppText.body(...)    : style = AppTextStyle.body;
  const AppText.caption(...) : style = AppTextStyle.caption;

  final String text;
  final AppTextStyle style;

  @override
  Widget build(BuildContext context) => Text(text, style: style.resolve(context), ...);
}
```

**Why not a "callable enum"** (`AppText.body('x')` as an enum method — that's how it used to be): a
method can never be a `const` expression. One non-const text leaf drags along every enclosing
`const Padding`, `const Center`, `const Expanded` — and `const` gets washed out of the tree.
Named constructors give exactly the same call site, but `const` stays legal.

Need a new style — **add a value to `AppTextStyle` and a constructor to `AppText`**, don't write a
`TextStyle` on the spot.

## Buttons: `AppButton` + `DwActionBuilder`

A button is an ordinary app widget. From the framework you take only `DwActionBuilder`: it holds the
"running" flag, **blocks a repeated tap**, validates the `Form` on `requireValidation`, drops focus —
and hands back a ready `onPressed` (`null` while the action runs) and `busy`.

```dart
AppButton.primary(
  l10n.saveAction,
  onTap: dw.action(
    (context) => dw.repo.saveModel(model),
    onSuccessNotification: l10n.saved,
  ),
)
```

```dart
// ui_kit/theme/app_button.dart — also a widget with named constructors
// (AppButton.primary / .secondary / .text). The variant is chosen by a real
// Material widget, so the outlined style is worn by OutlinedButton, not by a
// repainted ElevatedButton.
DwActionBuilder(
  action: onTap,
  requireValidation: requireValidation,
  unfocusOnTap: unfocusOnTap,
  builder: (context, onPressed, busy) => switch (_variant) {
    _AppButtonVariant.primary   => ElevatedButton(style: ..., onPressed: onPressed, child: child),
    _AppButtonVariant.secondary => OutlinedButton(style: ..., onPressed: onPressed, child: child),
    _AppButtonVariant.text      => TextButton(style: ..., onPressed: onPressed, child: child),
  },
)
```

**Button width is not a kit parameter.** A Material button shrinks to its content by itself, and
"full width" in Flutter is done by the parent: `SizedBox(width: double.infinity)` or `Expanded`. Don't
introduce width-mode enums — introduce a parent.

⚠️ **`requireValidation: true` requires a `Form` up the tree.** With no form there is nothing to
validate: the action will run, and in debug the framework's `assert` will fire. Don't set the flag
"just in case".

**A label inside a kit widget must be able to shrink.** A row of an icon and text in a `Row` with
`mainAxisSize.min` overflows as soon as the label doesn't fit the allotted width — and instead of a
button the user sees a red `RenderFlex overflowed` stripe. Text in such a row is always
`Flexible` + `maxLines: 1` + `TextOverflow.ellipsis`:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (leading != null) ...[leading!, const SizedBox(width: 8)],
    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
  ],
)
```

This applies to any kit widget with text in a row, not just a button. A widget test at a narrow width
(`SizedBox(width: 360)` + `expect(tester.takeException(), isNull)`) catches this immediately — and it
catches long-standing overflows nobody knew about, because the screen was only ever opened wide.

**`DwActionBuilder` is not only for buttons.** Any tap (`ListTile`, an icon, a card, a swipe) is made
safe by the same builder — don't hand-roll a `bool _busy`:

```dart
DwActionBuilder(
  action: deleteAction,
  builder: (context, onPressed, busy) => ListTile(
    onTap: onPressed,
    trailing: busy ? const CircularProgressIndicator() : const Icon(Icons.delete),
  ),
)
```

Division of labor: **`DwUiAction` — what the action does** (confirmation, notifications, follow-up,
error report), **`DwActionBuilder` — what happens in the UI while it runs**.

## Theme and breakpoints

**The theme lives in the kit, not in the app root.** `ThemeData` is styles, and styles live in the kit;
the root only mounts it. No `ThemeExtension` from the framework needs to be registered: `AppText`/
`AppButton` know their styles themselves.

```dart
// ui_kit/theme/app_theme.dart
abstract final class AppTheme {
  static const Color _seed = Color.fromARGB(255, 4, 49, 57);

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    bottomNavigationBarTheme: ..., // everything that must look the same everywhere goes here
  );
}

// the app
MaterialApp.router(theme: AppTheme.light, ...)
```

A color set on a widget is a color the next screen will forget about. If something must look the same
across the whole app, its place is in `AppTheme`, not in widget parameters.

Access to the theme goes through a kit extension (raw access is allowed by the lint only here):

```dart
// ui_kit/theme/app_context.dart
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 600;      // where mobile layout ends
  static const double deviceFrameMinWidth = 1024; // where the desktop shell draws the phone frame
}

extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isMobile =>
      MediaQuery.sizeOf(this).width <= AppBreakpoints.mobileMaxWidth;
}
```

These are **two different questions**, and they need two constants: "is this mobile layout" and "is
there enough width to frame a phone on desktop". On a single threshold a 700px browser window gets a
phone frame.

## Structure

```
lib/ui_kit/
  ui_kit.dart              // root: imports + part directives + export dartway_flutter
  1_essentials/            // basics: checkbox, input, multi_link_text
  2_frequent/              // frequent: card, bottom sheet, rating
  3_special/               // narrow, grouped by feature: pin code, chat bubble
  theme/                   // app_theme.dart, app_text.dart, app_button.dart, app_context.dart
  layout/                  // device_frame_shell.dart
  utils/                   // conditional_parent.dart, formatters, date labels
```

The numbered prefixes keep the kit sorted by usage frequency — the most needed on top.

## Best practices

- Props are minimal and semantic, not visual details.
- Don't breed variants by copy-paste — composition and extensions (see `dartway-clean-code`).
- Don't put outer `padding`/`margin` inside a component — the parent sets the spacing.
- Consistency beats visual hacks.
- Tempted by a "client-specific hack" inside a framework widget — that's a signal that an extension
  point is missing. Introduce it in the kit, don't fork `dartway_flutter`.
