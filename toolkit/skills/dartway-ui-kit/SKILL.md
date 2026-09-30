---
name: dartway-ui-kit
description: >-
  The UI kit of a DartWay app — source in lib/ui_kit/, owned by the project (the framework ships no
  design): one import, part-of structure, no raw styles outside it, kit widgets that take no visual
  types, AppSpace spacing, assets as an enum plus one renderer, AppText/AppTextStyle, AppButton over
  DwActionBuilder, the theme, the one spinner, the read views, and localization. Use when creating or
  editing UI components, styles, themes, buttons, texts, or when adding widgets to the kit.
---

# DartWay — the UI kit (`dartway-ui-kit`)

**The kit is the app's code**, in `__FLUTTER_PKG__/lib/ui_kit/`; `dartway_core_flutter` has no button,
text widget or theme, and there is no kit package. The framework gives the mechanics only:
`DwActionBuilder` and the read widgets whose loading and failed views are the kit's. Kit widgets carry
no `Dw` prefix — `App*` where Flutter has the name, none otherwise. A client-specific need inside a
framework widget is an extension point in the kit, never a fork of `dartway_core_flutter`.

```
lib/ui_kit/ui_kit.dart     imports, part directives, export of dartway_core_flutter
  1_essentials/  2_frequent/  3_special/   by frequency of use
  assets/  theme/  layout/  utils/
```

## The rules the checks hold, and how to satisfy them

- Everything outside the kit imports `ui_kit.dart` only, and each kit file is `part of '../ui_kit.dart';`.
- **No raw styling outside the kit** (`forbiddenUiUsage`, and the lint `forbidden_ui_style_usage`):
  where Flutter demands a style (`Icon(color:)`, `InputDecoration.labelStyle`, a third-party `style:`),
  the whole widget moves into the kit, which takes the style from a token
  (`AppTextStyle.body.resolve(context)`). Never `// ignore:`. Raw theme access is allowed anywhere in
  `ui_kit/` and nowhere else; `theme/app_context.dart` defines the shortcuts (`context.colorScheme`,
  `textTheme`) and the breakpoints — two constants for two questions (mobile layout; room for a device
  frame).
- **Spacing is `AppSpace`** (`ui_kit/theme/app_space.dart`, steps named by value, `s2`…`s48`):
  `Gap(AppSpace.s12)`, `EdgeInsets.all(AppSpace.s16)`, `Row(spacing: AppSpace.s8)` (`rawSpacing`). A
  missing value becomes a step named by its value; never round a visible value. A component's own
  dimension (an avatar's size) lives in the component.
- **A widget never decides its own size** — `Expanded` or `SizedBox.expand` at the root of `build`
  (`widgetSizesItself`) — and never sets its own outer padding or margin: space is the parent's.
- **`AppProgressIndicator`** (`1_essentials/`) is the one spinner (`forbiddenProgressIndicator`) — a read
  without a placeholder, an upload, a busy button; `lib/core/dw_core.dart` hands `readLoadingBuilder` and
  `readFailedBuilder` (`LoadFailedMessage`) to the framework once. The frames of dialogs and sheets live
  in `2_frequent/`; when to open them: `dartway-navigation`.
- A kit widget's own state is hooks (`dartway-feature-scaffold`); it takes a value and an `onChanged`,
  never a caller's `ValueNotifier`.

**Warnings the kit owns:** `uiKitContainsText` — a string literal in the kit (the kit takes every
visible string as a parameter and never reads `context.l10n`; `fontFamily` strings are exempt);
`uiKitConstStyle` — a `static const Color`/`TextStyle` outside `ui_kit/theme/`: colours and text styles
come from the context, or a second theme rewrites the kit (geometry, like a radius, stays `const`);
`forbiddenAssetPath` — an `assets/` path outside the kit.

## A kit widget takes no visual types

The kit is pure visuals with minimal props: no business logic, no state of the app's, no app models, no
switch on a domain enum — the feature maps the domain to the kit's parameters, and a domain enum does
not move into the kit to get around that (its texts would come along). No `Color`, `TextStyle`,
`EdgeInsets`, `BorderRadius`, `BoxDecoration` in a kit widget's constructor, or every feature is forced
to know the palette:

- **a named constructor** when the variant is static at the call site — `AppButton.primary` / `.secondary`
  / `.text`;
- **a semantic parameter** when the caller has a runtime value — `selected: isActive`, named by meaning
  (`selected`, `fillsScreen`), never by look (`isDark`, `withShadow`); a flag that changes several things
  says so in its doc.

`padding` outward is fine: air inside a block is the screen's call. A feature assembling a surface by
hand usually means the primitive lacks a variant — add it to the primitive, keeping every token value as
it was; never breed variants by copy-paste. A class in a feature that only re-assembles its parameters
into one kit widget is deleted, or becomes a named constructor of that widget.

Units — a card, a feed, a section header — own their geometry, safe-area insets and published sizes (a
card's height is a constant of the kit widget, which a feature may read but not set). Text in a `Row`
inside a kit widget is `Flexible` (wrap, or one line with ellipsis); a widget test at 360 px with
`expect(tester.takeException(), isNull)` finds overflows. Keyboard-dependent layout: `dartway-on-device`.

## Assets, text, buttons, theme

- **Assets**: an enum dictionary in `assets/app_icon.dart` — `brandMark('assets/dartway_mark.svg')` — and
  `AppIconView(AppIcon.brandMark, size: 24)`, the only place calling `Image.asset`/`SvgPicture`. One
  `size`, not a width and a height: something filling an area by width is a cover with a widget of its
  own. No `flutter_gen`; a path to a missing file is `assetPathMissing`. Fonts come through text styles;
  sounds and video are not the kit's.
- **Text**: `AppText.title(…)`, `.body`, `.caption` — `const` constructors — in 99% of places;
  `AppTextStyle` is the token where Flutter demands a `TextStyle`. A new style is a value of
  `AppTextStyle` and a constructor of `AppText` (`theme/app_text.dart`), never a `TextStyle` on the spot.
- **Buttons**: `AppButton` (`theme/app_button.dart`) over `DwActionBuilder` (`dartway-data-layer` §4);
  its width is the parent's; `requireValidation` needs a `Form` above it.
- **Theme**: `AppTheme` (`theme/app_theme.dart`) holds `ThemeData`; what must look the same everywhere
  goes there, not into widget parameters.

## Localization

**Every project is localized, and user-visible text is never a literal.** The wiring
(`l10nNotWired` holds it): `flutter_localizations` and `generate: true` in the pubspec, `l10n.yaml`,
`lib/l10n/*.arb` with the generated output committed, `appLocaleProvider`, `context.l10n` in widgets and
`appL10n` for code outside the tree. **A new string goes into every `.arb`**, then `flutter gen-l10n`,
output committed; a second language is added deliberately. Outside the kit nothing mechanical finds a
hardcoded string — `/dartway-checkup` reads for it. Refusal texts: `dartway-data-layer` §5. Tests and the
locale: `dartway-testing`. Text composed on the server (a code message, an e-mail) has no rule yet; a
project sending it in several languages decides how and says so.
