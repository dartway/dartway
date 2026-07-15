---
name: dartway-ui-kit
description: >-
  Правила UI Kit в DartWay Flutter: кит живёт ИСХОДНИКОМ в приложении (lib/ui_kit/) — фреймворк не
  поставляет ни кнопок, ни текста, ни темы. AppText/AppButton — виджеты приложения с именованными
  конструкторами, AppTextStyle — токен для мест, где Flutter требует TextStyle; тема (AppTheme) тоже
  в ките. DwActionBuilder из фреймворка защищает действие (busy, повторный тап, валидация формы).
  Внутри фич запрещены Color/TextStyle/BorderRadius/Theme.of/context.textTheme/colorScheme; импорт
  только ui_kit.dart; part-of структура. Использовать при создании/правке UI-компонентов, стилей,
  цветов, тем, кнопок, при добавлении виджетов в ui_kit.
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
   **запрещено**: `Color`, `TextStyle`, `BorderRadius`, `Colors.*`, `Theme.of(context)`,
   `context.theme`, `context.textTheme`, `context.colorScheme`. Это не пожелание — правило
   `forbidden_ui_style_usage` из `dartway_lints` (через `custom_lint`) разрешает их **только внутри
   `ui_kit/`** и различает `BuildContext` по типу, а не по имени переменной.

   **Что делать, когда Flutter требует стиль, а не виджет** (`Icon(color:)`,
   `InputDecoration.labelStyle`, `TextSpan`, чужой виджет со `style:`): такой виджет **целиком
   переезжает в кит**, а фича его композит. Внутри кита стиль берётся токеном
   (`AppTextStyle.body.resolve(context)`). Обход правила через `// ignore:` — это стиль, сбежавший
   из кита; следующий экран о нём уже не узнает.
4. **Изолированный визуальный слой.** Кит не зависит от бизнес-логики и стейта. Компонент =
   чистые визуалы + минимальные пропсы.
5. **Переиспользуемое, не фиче-специфичное.** В ките — общие строительные блоки. Фиче-специфичное
   живёт внутри фичи.

## Текст: виджет с именованными конструкторами + токен-enum

Две разные сущности, и их нельзя схлопывать в одну:

- **`AppText`** — виджет с `const`-конструкторами. Это то, что пишут в 99% мест.
- **`AppTextStyle`** — токен. Он нужен там, где Flutter требует именно `TextStyle`, а не виджет
  (`InputDecoration.labelStyle`, `TextSpan`, `Icon`, чужие виджеты со `style:`).

```dart
const AppText.title('DartWay.dev')          // const работает — и охватывающие const тоже
AppText.body(post.description)
AppText.caption('${date.dayLabel} · ${date.timeLabel}')
```

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

**Почему не «вызываемый enum»** (`AppText.body('x')` как метод enum'а — так было раньше): метод
никогда не может быть `const`-выражением. Один неконстантный текстовый лист утаскивает за собой все
охватывающие `const Padding`, `const Center`, `const Expanded` — и `const` вымывается из дерева.
Именованные конструкторы дают ровно тот же call-site, но `const` остаётся законным.

Нужен новый стиль — **добавь значение в `AppTextStyle` и конструктор в `AppText`**, не пиши
`TextStyle` на месте.

## Кнопки: `AppButton` + `DwActionBuilder`

Кнопка — обычный виджет приложения. От фреймворка берётся только `DwActionBuilder`: он держит флаг
«выполняется», **блокирует повторное нажатие**, при `requireValidation` валидирует `Form`, снимает
фокус — и отдаёт готовые `onPressed` (`null`, пока действие бежит) и `busy`.

```dart
AppButton.primary(
  l10n.saveAction,
  onTap: dw.action(
    (context) => ref.saveModel(model),
    onSuccessNotification: l10n.saved,
  ),
)
```

```dart
// ui_kit/theme/app_button.dart — тоже виджет с именованными конструкторами
// (AppButton.primary / .secondary / .text). Вариант выбирает настоящий
// Material-виджет, поэтому outlined-стиль носит OutlinedButton, а не крашеный
// ElevatedButton.
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

**Ширина кнопки — не параметр кита.** Material-кнопка сама сжимается по контенту, а «на всю ширину»
во Flutter делает родитель: `SizedBox(width: double.infinity)` или `Expanded`. Не заводи enum'ы
режимов ширины — заводи родителя.

⚠️ **`requireValidation: true` требует `Form` выше по дереву.** Без формы валидировать нечего:
действие выполнится, а в дебаге сработает `assert` фреймворка. Не вешай флаг «на всякий случай».

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

**Тема живёт в ките, а не в корне приложения.** `ThemeData` — это стили, а стили живут в ките; корень
только монтирует её. Никаких `ThemeExtension` от фреймворка регистрировать не нужно: `AppText`/
`AppButton` знают свои стили сами.

```dart
// ui_kit/theme/app_theme.dart
abstract final class AppTheme {
  static const Color _seed = Color.fromARGB(255, 4, 49, 57);

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    bottomNavigationBarTheme: ..., // всё, что должно выглядеть одинаково везде — здесь
  );
}

// приложение
MaterialApp.router(theme: AppTheme.light, ...)
```

Цвет, выставленный на виджете, — это цвет, о котором забудет следующий экран. Если что-то должно
выглядеть одинаково во всём приложении, ему место в `AppTheme`, а не в параметрах виджета.

Доступ к теме — через extension кита (raw-доступ линт разрешает только здесь):

```dart
// ui_kit/theme/app_context.dart
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 600;      // где кончается мобильная вёрстка
  static const double deviceFrameMinWidth = 1024; // где десктоп-шелл рисует рамку телефона
}

extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isMobile =>
      MediaQuery.sizeOf(this).width <= AppBreakpoints.mobileMaxWidth;
}
```

Это **два разных вопроса**, и им нужны две константы: «мобильная ли вёрстка» и «хватает ли ширины,
чтобы обрамить телефон на десктопе». На одном пороге окно браузера в 700px получает рамку телефона.

## Структура

```
lib/ui_kit/
  ui_kit.dart              // корень: импорты + part-директивы + export dartway_flutter
  1_essentials/            // базовое: чекбокс, инпут, multi_link_text
  2_frequent/              // частое: карточка, bottom sheet, рейтинг
  3_special/               // узкое, сгруппировано по фиче: pin-код, чат-бабл
  theme/                   // app_theme.dart, app_text.dart, app_button.dart, app_context.dart
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
