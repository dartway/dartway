---
name: dartway-ui-kit
description: >-
  Правила UI Kit в DartWay Flutter: кит живёт ИСХОДНИКОМ в приложении (lib/ui_kit/) — фреймворк не
  поставляет ни кнопок, ни текста, ни темы. AppText/AppButton — вызываемые enum'ы приложения;
  DwActionBuilder из фреймворка защищает действие (busy, повторный тап, валидация формы). Внутри
  фич запрещены Color/TextStyle/BorderRadius/context.textTheme/colorScheme; импорт только
  ui_kit.dart; part-of структура. Использовать при создании/правке UI-компонентов, стилей, цветов,
  тем, кнопок, при добавлении виджетов в ui_kit.
---

# DartWay — UI Kit

**Кит принадлежит приложению.** Он лежит исходником в `__FLUTTER_PKG__/lib/ui_kit/`, его кладёт
`dartway create`, и дальше проект правит его свободно — это его код, а не зависимость.

**Фреймворк не поставляет дизайн.** В `dartway_flutter` **нет** `DwButton`, `DwText`,
`DwFlutterTheme`, `DwColorPreset` и пресетов стилей. Не ищи их и не импортируй — их не существует.
Пакета `dartway_ui_kit` тоже нет и не будет: иначе у приложения оказалось бы два кита — наш в
зависимостях и свой в `lib/`, и на каждый `AppButton` вставал бы вопрос «чей это».

Фреймворк даёт ровно то, что приложению не следует изобретать заново: **`DwActionBuilder`**
(механика действия) и **`dwBuildAsync`** (единый рендер загрузки/ошибки/данных).

**Конвенция имён.** `Dw*` — фреймворк: приезжает извне, обновляется, не правь. Кит — код
приложения, префикса `Dw` в нём нет: `App*` там, где иначе коллизия с Flutter (`AppText`,
`AppButton`), и без префикса, где коллизии нет (`ConditionalParent`, `MultiLinkText`,
`DeviceFrameShell`). По одному взгляду на идентификатор видно, твоё это или фреймворка.

## Core-принципы

1. **Один импорт.** Компоненты импортируются только через корневой `ui_kit.dart`. Никогда не
   импортируй отдельные кнопки/цвета/стили напрямую.
2. **Всё объявлено в `ui_kit.dart`.** Каждый файл компонента начинается с `part of '../ui_kit.dart';`.
   Корневой файл собирает всё `part`-директивами и реэкспортирует `dartway_flutter`.
3. **Никакого raw-стайлинга в фичах.** Внутри `lib/<feature>` (`app/`/`auth/`/`common/`)
   **запрещено**: `Color`, `TextStyle`, `BorderRadius`, `context.textTheme`, `context.colorScheme`.
   Это не пожелание — правило `forbidden_ui_style_usage` в `dartway_lints` разрешает их **только
   внутри `ui_kit/`**.
4. **Изолированный визуальный слой.** Кит не зависит от бизнес-логики и стейта. Компонент =
   чистые визуалы + минимальные пропсы.
5. **Переиспользуемое, не фиче-специфичное.** В ките — общие строительные блоки. Фиче-специфичное
   живёт внутри фичи.

## Текст: вызываемый enum

Стиль — enum приложения, который **вызывается как виджет**. Резолв отложен до build-time (в момент
вызова `BuildContext`а ещё нет), поэтому вызов возвращает виджет, а не `TextStyle`.

```dart
AppText.title(l10n.profile)
AppText.body(post.description)
AppText.caption('${date.dayLabel} · ${date.timeLabel}')
```

```dart
// ui_kit/theme/app_text.dart
enum AppText {
  title, body, link, caption;

  TextStyle resolve(BuildContext context) => switch (this) {
    AppText.title => context.textTheme.titleLarge!
        .copyWith(color: context.colorScheme.onSurface),
    // ...
  };

  Widget call(String text, {TextAlign? textAlign, int? maxLines}) =>
      _AppTextView(text, preset: this, textAlign: textAlign, maxLines: maxLines);
}
```

Нужен новый стиль — **добавь значение в enum**, не пиши `TextStyle` на месте.

## Кнопки: `AppButton` + `DwActionBuilder`

Кнопка — обычный виджет приложения. От фреймворка берётся только `DwActionBuilder`: он держит флаг
«выполняется», **блокирует повторное нажатие**, при `requireValidation` валидирует `Form`, снимает
фокус — и отдаёт готовые `onPressed` (`null`, пока действие бежит) и `busy`.

```dart
AppButton.primary(
  l10n.saveAction,
  onTap: DwUiAction.create(
    (context) => ref.saveModel(model),
    onSuccessNotification: l10n.saved,
  ),
)
```

```dart
// ui_kit/theme/app_button.dart — вариант выбирает настоящий Material-виджет,
// поэтому outlined-стиль носит OutlinedButton, а не крашеный ElevatedButton
DwActionBuilder(
  action: onTap,
  requireValidation: requireValidation,
  builder: (context, onPressed, busy) => switch (variant) {
    AppButton.primary   => ElevatedButton(style: ..., onPressed: onPressed, child: child),
    AppButton.secondary => OutlinedButton(style: ..., onPressed: onPressed, child: child),
    AppButton.text      => TextButton(style: ..., onPressed: onPressed, child: child),
  },
)
```

**`DwActionBuilder` — не только для кнопок.** Любой тап (`ListTile`, иконка, карточка, свайп)
делается безопасным тем же билдером — не городи `bool _busy` руками:

```dart
DwActionBuilder(
  action: deleteAction,
  builder: (context, onPressed, busy) => ListTile(
    onTap: onPressed,
    trailing: busy ? const CircularProgressIndicator() : const Icon(Icons.delete),
  ),
)
```

Разделение труда: **`DwUiAction` — что действие делает** (подтверждение, уведомления, follow-up,
отчёт об ошибке), **`DwActionBuilder` — что происходит в UI, пока оно бежит**.

## Тема и брейкпоинты

Тема приложения — обычная `ThemeData` в корне. Никаких `ThemeExtension` от фреймворка
регистрировать не нужно: `AppText`/`AppButton` знают свои стили сами, они лежат рядом с ними.

Доступ к теме — через extension кита (raw-доступ линт разрешает только здесь):

```dart
// ui_kit/theme/app_context.dart
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 600;   // единственная точка правды
}

extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isMobile =>
      MediaQuery.sizeOf(this).width <= AppBreakpoints.mobileMaxWidth;
}
```

## Структура

```
lib/ui_kit/
  ui_kit.dart              // корень: импорты + part-директивы + export dartway_flutter
  1_essentials/            // базовое: чекбокс, инпут, multi_link_text
  2_frequent/              // частое: карточка, bottom sheet
  3_special/               // узкое, сгруппировано по фиче: pin-код, чат-бабл
  theme/                   // app_text.dart, app_button.dart, app_context.dart
  layout/                  // device_frame_shell.dart
  utils/                   // conditional_parent.dart, форматтеры, лейблы дат
```

Нумерованные префиксы держат кит отсортированным по частоте использования — самое нужное сверху.

## Best practices

- Пропсы — минимальные и семантичные, не визуальные детали.
- Не плоди варианты копипастой — композиция и extensions (см. `dartway-clean-code`).
- Не клади внешние `padding`/`margin` внутрь компонента — отступ задаёт родитель.
- Консистентность важнее визуальных хаков.
- Захотелось «хака под клиента» внутри виджета фреймворка — это сигнал, что не хватает точки
  расширения. Заводи её в ките, а не форкай `dartway_flutter`.
