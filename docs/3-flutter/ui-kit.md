# Why does DartWay ship no design?

`dartway_flutter` contains no `DwButton`, no `DwText`, no theme, no color presets. There is no
`dartway_ui_kit` package, and there will not be one. Do not look for them — they do not exist.

This is the one deliberate hole in the framework, and it is worth understanding before you try to
fill it.

A design system is the thing every serious app ends up owning. Shipping one as a dependency starts
an argument about the corner radius of a button that the framework can never win: either the app
bends its design to the package, or the package grows a parameter for every disagreement until it is
a worse Flutter. Worse, an app would then have **two** kits — ours in `pubspec.yaml` and its own in
`lib/` — and every `AppButton` in a review would raise the question "whose is this?".

So the kit belongs to the app. `dartway create` scaffolds it as **source** into
`lib/ui_kit/`, and from that moment it is the project's own code: edit it, delete from it, rewrite
it. Nothing updates it from under you.

## What the framework does ship

Exactly the mechanisms a kit should not have to reinvent, and nothing that has a look:

- **`DwActionBuilder`** — the action guard: the in-flight flag, the suppressed second tap, optional
  `Form` validation, focus handling. See [actions](actions.md).
- **`dwBuildAsync` / `dwBuildListAsync`** — one rendering of loading / error / data, with skeletons
  built from your own widget. See [the data layer](data-layer.md).

Both are widget-agnostic on purpose. `DwActionBuilder` hands you `onPressed` and `busy` and lets you
build anything with them — a button, a list tile, an icon, a card. It has no idea what a button
looks like, and it is not supposed to.

The app's button is then an ordinary app widget wrapping the guard:

```dart
class AppButton extends StatelessWidget {
  const AppButton.primary(this.label, {required this.onTap, ...})
      : _variant = _AppButtonVariant.primary;

  @override
  Widget build(BuildContext context) => DwActionBuilder(
    action: onTap,
    requireValidation: requireValidation,
    builder: (context, onPressed, busy) => switch (_variant) {
      _AppButtonVariant.primary => ElevatedButton(style: ..., onPressed: onPressed, child: child),
      _AppButtonVariant.secondary => OutlinedButton(style: ..., onPressed: onPressed, child: child),
      _AppButtonVariant.text => TextButton(style: ..., onPressed: onPressed, child: child),
    },
  );
```

Note the variant picking a real Material widget rather than repainting one: an outlined style is
worn by an `OutlinedButton`, so focus, hover and disabled states come from Flutter instead of being
re-derived.

## Naming: whose symbol is this?

`Dw*` is the framework — it arrives from outside, it gets updated, you do not edit it. The kit is
app code and carries no `Dw` prefix: `App*` where a bare name would collide with Flutter (`AppText`,
`AppButton`, `AppCard`), and no prefix at all where there is no collision (`ConditionalParent`,
`MultiLinkText`, `DeviceFrameShell`). One look at an identifier tells you whether it is yours.

## One import, one place for styles

The kit is assembled through a single root file. Every component is `part of '../ui_kit.dart';`, and
the root file gathers them with `part` directives and re-exports `dartway_flutter`. Features import
`ui_kit.dart` and nothing else from the kit — importing a component file directly is an error
(`forbiddenUiKitImport`), because it is how a kit stops being one surface.

Inside feature code, raw styling is forbidden: `Color`, `TextStyle`, `BorderRadius`, `Colors.*`,
`Theme.of(context)`, `context.theme`, `context.textTheme`, `context.colorScheme`. This is not a
wish. `dartway_lints` ships `forbidden_ui_style_usage` (a `custom_lint` rule) which allows all of
them only inside a path containing `ui_kit`, and recognises a `BuildContext` **by its static type**,
so renaming the variable to `ctx` does not help. `dartway check` flags the same patterns
independently.

**When Flutter demands a style rather than a widget** — `Icon(color:)`,
`InputDecoration.labelStyle`, a `TextSpan`, a third-party widget with `style:` — that widget **moves
into the kit whole** and the feature composes it. Inside the kit the style comes from a token
(`AppTextStyle.body.resolve(context)`). Silencing the rule with `// ignore:` is a style that escaped
the kit, and the next screen will never learn it exists.

## The rule that makes the previous one hold

**A kit widget's public API accepts no visual types.** No `Color`, `TextStyle`, `EdgeInsets`,
`BorderRadius` or `BoxDecoration` in a constructor. The look is chosen by named constructors and
semantic parameters; what crosses the boundary is data, state and callbacks.

Without this rule the ban on raw styles is bypassed **by construction**. `AppColors.x` is a
perfectly legal symbol; as long as a kit widget accepts a color, every feature is *obliged* to know
the palette, and the lint has nothing to complain about. That is not hypothetical — on a production
project it produced 40 kit widgets with color fields, 268 palette lookups from feature code, and 48
of 131 tokens named after somebody else's feature: an event badge painted with
`settingsNavigationRowLeadingFill`.

**Review signal:** a feature reaching for a token named after a *different* feature. What is missing
is a kit constructor, not a color that looks close enough.

The same symptom shows up as a primitive that is simultaneously too weak and too open — one that
accepts `fillColor` and `borderRadius` from outside but cannot draw a border, so ten features grow
their own `Container(decoration: BoxDecoration(...))`. The cure is one edit to the primitive:

```dart
// ❌ forces the caller to know the color and the radius
const AppContainer.surface({required this.child, this.fillColor, this.borderRadius});

// ✅ the constructor picks the look; tone is a semantic enum; padding stays (that is layout)
const AppContainer.surface({required this.child, this.padding, this.onTap});
const AppContainer.tinted({required this.child, required this.tone});
const AppContainer.outlined({required this.child});

enum AppSurfaceTone { plain, muted, control, achieved }
```

Migrating without changing the visuals: walk every call site that passed a visual parameter and read
the value. Some pass exactly the default — drop the parameter. Some pass their own — they need a
constructor or a tone using **the same token**. No color and no radius may change value, or
"we reworked the primitive" becomes "the design drifted".

**`padding` outward is fine.** How much air there is inside a block is the screen's call. Color,
radius, shadow and border are not.

### Named constructor or semantic parameter

Both express meaning; the question is who chooses.

- **Named constructor** when the choice is static at the call site: `AppEventCard.compact` in a
  feed, `.wide` on a list screen. The caller always knows which one it wants.
- **Semantic parameter** when the caller holds a runtime value:
  `AppButton.filterChip(selected: isActive)`. Forcing a constructor choice here just moves a
  ten-line ternary into the feature.

Name a parameter by meaning (`selected`, `fillsScreen`), never by look (`isDark`, `withShadow`).

## Text: a widget and a token, not one clever thing

`AppText` is a widget with `const` named constructors — `AppText.title('DartWay')`,
`AppText.body(post.text)`. `AppTextStyle` is an enum of tokens with `resolve(context)`, for the
places where Flutter insists on a `TextStyle`.

They are separate for a concrete reason. A "callable preset" that both styles and renders
(`AppText.body('x')` as an enum method) can never be a `const` expression, and one non-const text
leaf drags every enclosing `const Padding`, `const Center` and `const Expanded` down with it. Named
constructors give the identical call site with `const` intact.

Need a new style? Add a value to `AppTextStyle` and a constructor to `AppText`. Do not write a
`TextStyle` on the spot.

## Theme and breakpoints live in the kit too

`ThemeData` is styles, and styles belong to the kit; the app root only mounts it
(`MaterialApp.router(theme: AppTheme.light)`). Anything that must look the same everywhere goes into
the theme, not into widget parameters — a color set on one widget is a color the next screen will
forget about.

Theme access is re-exposed through a kit extension, which is the one place the lint permits it:

```dart
extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isMobile => MediaQuery.sizeOf(this).width <= AppBreakpoints.mobileMaxWidth;
}
```

Breakpoints are the app's decision, so they are constants in the kit. Give each question its own
number: "is this a mobile layout" and "is this desktop wide enough to frame a phone" are two
different questions, and sharing one threshold means a 700px browser window gets a phone frame drawn
around it.

## The kit is a design system, not a folder of shared widgets

A card, a card feed, a section header with an "all" link, a screen surface — these are units. Their
geometry, padding, radii and background belong to the kit entirely, and a composite needed by
exactly one feature is still the kit (the example app files them under `3_special/`). What stays in
the feature is the mapping of the domain onto the kit's parameters, not layout.

Two consequences that are easy to get wrong:

- **System insets belong inside the kit widget.** A surface glued to the bottom must respect the
  bottom inset by definition. While the caller computes it, every next screen repeats the arithmetic
  — and one of them will forget.
- **Sizes are published by the kit.** The card height a feed needs is a kit constant
  (`AppEventCard.compactHeight`), not a public field on the feature. A feature may read a size; it
  may not assign one.

And the kit does not know the domain: it imports no app models and switches on no domain enums. If a
widget picks an image from the reason a course is locked, the widget moves into the kit with two
constructors and the domain `switch` stays in the feature as one line. The enum itself does not
move — its user-facing texts would come with it, and text constants have no place in the kit
(`dartway check` warns on them).

Finally: tempted to add a client-specific hack inside a framework widget? That is the signal an
extension point is missing. Add it to your kit — do not fork `dartway_flutter`.
