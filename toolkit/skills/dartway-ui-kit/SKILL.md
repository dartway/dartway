---
name: dartway-ui-kit
description: >-
  Правила UI Kit в DartWay Flutter: UI Kit — единственный источник стилей; внутри фич
  (app/auth/common) запрещены прямые Color/TextStyle/BorderRadius/context.textTheme/colorScheme;
  импорт только ui_kit.dart; part-of структура; ExtendedColor/MaterialTheme через статические
  геттеры; компоненты — чистые визуалы без логики и стейта, переиспользуемые. Использовать при
  создании/правке UI-компонентов, стилей, цветов, тем, при добавлении виджетов в ui_kit.
---

# DartWay — UI Kit

UI Kit — **единственный разрешённый источник** элементов дизайн-системы. Это гарантирует единые стили и компоненты во всех фичах. (Пакет `dartway_ui_kit` в разработке — пока это проектный стандарт.) См. также `__FLUTTER_PKG__/CLAUDE.md`.

## Core-принципы

1. **Один импорт.** Компоненты импортируются только через корневой `ui_kit.dart`. Никогда не импортируй отдельные кнопки/цвета/стили напрямую.
2. **Всё объявлено в `ui_kit.dart`.** Каждый файл компонента начинается с `part of 'ui_kit.dart';`. Корневой файл собирает и экспортирует всё. Фичи импортируют **только** `ui_kit.dart`.
3. **Никакого raw-стайлинга в фичах.** Внутри `lib/<feature>` (app/auth/common) **запрещено**: `Color`, `TextStyle`, `BorderRadius`, `context.textTheme`, `context.colorScheme`. Всегда — готовые компоненты UI Kit.
4. **Изолированный визуальный слой.** UI Kit не зависит от бизнес-логики и стейта. Компонент = чистые визуалы + минимальные пропсы.
5. **Переиспользуемое, не фиче-специфичное.** В UI Kit только общие строительные блоки (кнопки, инпуты, карточки, списки, модалки). Фиче-специфичное — внутри фичи.

## Цвета и темы

DartWay использует Extended Material Colors с `ColorFamily` (несколько тем: light/dark/high-contrast). Цвета централизованы, доступ — через статические геттеры. Фичи никогда не лезут в `context`-темы напрямую.

```dart
final primary = MaterialTheme.colorScheme.primary;
final danger = ExtendedColor.danger.primary;
```

## Структура

```
lib/ui_kit/
  ui_kit.dart          // корень: part-директивы + экспорт
  buttons/
    primary_button.dart
    secondary_button.dart
  inputs/
    text_field.dart
  surfaces/
    card.dart
  theme/
    material_theme.dart
    extended_color.dart
```

```dart
// ui_kit.dart
part 'buttons/primary_button.dart';
part 'buttons/secondary_button.dart';
part 'inputs/text_field.dart';
part 'surfaces/card.dart';
part 'theme/material_theme.dart';
part 'theme/extended_color.dart';
```

## Best practices

- Пропсы — минимальные и семантичные (`isPrimary`, `isDanger`), не визуальные детали.
- Не плоди варианты копипастой — композиция и extensions (см. `dartway-clean-code`: DRY, composition over inheritance).
- Консистентность важнее визуальных хаков.
- Не клади внешние `padding`/`margin` внутрь компонента — отступ задаёт родитель.
