---
name: dartway-feature-scaffold
description: >-
  Пошаговый playbook создания новой фичи в DartWay end-to-end (Flutter + Serverpod):
  навигация → UI entry point → state/logic через data-layer и Riverpod → backend CRUD-конфиги
  → модели/БД → тесты. Структура фичи (entry point + widgets + logic), изоляция (импорт только
  entry point), границы domain/app/ui_kit, паспорт фичи `DwFeatureSpec` в её же файле.
  Использовать при добавлении новой функциональности, экрана, флоу или модели.
---

# DartWay — создание фичи (end-to-end)

Playbook добавления новой фичи. Фича в DartWay **маленькая и самодостаточная** и проходит сквозь сервер и флаттер. По возможности выделяй каждый функциональный виджет в отдельную фичу, если они не делят действительно критичный стейт.

См. также: `__FLUTTER_PKG__/CLAUDE.md`, `__SERVER_PKG__/CLAUDE.md`, скиллы `dartway-crud-config`, `dartway-data-layer`, `dartway-models`, `dartway-navigation`, `dartway-ui-kit`, `dartway-clean-code`, `dartway-finish`.

> Если фича уже существует — **сначала прочитай её док** `docs/2_features/<FEATURE>.md` (там текущее поведение и `code-anchors`). Меняешь поведение — обновишь и док (закон №6).

## Структура фичи (Flutter)

```
lib/app/<feature>/
  <feature>_page.dart        // entry point — единственный публичный файл
  widgets/
    <feature>_list.dart
    <feature>_item.dart
  logic/                     // опционально
    <feature>_provider.dart
    <feature>_filter.dart
```

- **Entry Point** — единственный публичный файл (Page/Widget/context-extension вроде `context.showInviteDialog()`). Извне фичи импортируется только он.
- **widgets/** — визуальные блоки фичи.
- **logic/** — провайдеры/enum'ы/хелперы только этой фичи.
- Кросс-фичевая бизнес-логика → `lib/domain` (extensions на моделях), не внутри фичи.
- Стили → только `ui_kit.dart`.

## Порядок работы

### 1. Навигация
Определи точку входа в фичу и точки выхода. Если нужен роут — добавь (enum-роут, см. скилл `dartway-navigation`).

### 2. Интерфейс (UI)
Создай entry point (Page/Widget/extension), набросай layout (кнопки, списки, поля). Стили — из UI Kit. Данные на этом шаге можно замокать/захардкодить.

Entry point-виджет **объявляет, что он за фича** — `implements DwFeature` с `DwFeatureSpec` прямо в своём файле (см. «Паспорт фичи» ниже). Без этого `dartway check` даёт ворнинг `featureSpecMissing`.

### 3. State & Logic
Определи, какие данные нужны UI. Доступ к данным — только через `dw.repo`: чтение — провайдеры `dw.repo.model`/`maybeModel`/`modelList` под родным `ref` (`ref.watch(...)` реактивно, `ref.read(....future)` разово), запись — методы `dw.repo.saveModel`/`deleteModel`. Для сложных сценариев/переиспользования внутри фичи — Riverpod-провайдер. Локальный стейт — Riverpod + StatefulWidget + flutter_hooks. Опиши все действия пользователя (create/edit/delete) до привязки к бэкенду.

### 4. Backend (CRUD-конфиги)
Каждое действие пользователя маппится на CRUD-слой — никаких произвольных эндпоинтов. Используй `SaveConfig`/`DeleteConfig`/`GetModelConfig`/`GetListConfig`, ответы оборачивай в `DwModelWrapper`. В конфигах: права, валидации, pre/post-обработка, сайд-эффекты. Детали — скилл `dartway-crud-config`.

### 5. Модели & БД
Уточни модели под реальные нужды фичи: поля и связи (1–1, 1–N, N–N). Поле nullable — только если значение реально может отсутствовать в домене, не ради удобства UI. Схема отражает доменную реальность. После правки YAML — `serverpod generate` + миграция.

### 6. Тесты
Сервер: юнит-тесты на каждый CRUD-конфиг (права, валидации, pre/post, sideEffects), тесты Event-моделей. Флаттер: widget-тест на entry point, provider-тесты на логику, integration — на навигацию и ключевые действия. Порог — по сложности (см. `dartway-clean-code`, Часть 3).

### 7. Завершение (закон №6)
Прогони скилл `dartway-finish`: аудит диффа против контракта, проверка дрейфа дока фичи (`docs/2_features/<FEATURE>.md`) и покрытия тестами. Новую фичу — заведи в `docs/2_features/` с шапкой `code-anchors`. Скилл показывает предложения и применяет только подтверждённое.

## Паспорт фичи (`DwFeatureSpec`)

Фича описывает себя **в своём же файле**, рядом с кодом. Не в отдельном реестре и не только в `docs/2_features/` — описание, живущее вдали от кода, расходится с ним на первой же правке. Это же описание читают отчёты об ошибках, DartWay Studio и агент.

```dart
class BookingListPage extends ConsumerWidget implements DwFeature {
  const BookingListPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'bookings/list',
    title: 'Мои записи',
    purpose: 'Клиент видит, на что записан, и может отменить запись.',
    behaviors: [
      'Записи отсортированы по дате, ближайшая сверху.',
      'Отмена убирает запись из списка без перезагрузки.',
      'Прошедшую запись отменить нельзя — кнопки нет.',
    ],
    requirements: [
      'Клиент видит только свои записи — решает accessFilter на бэке, не виджет.',
    ],
    implementationNotes: [
      'Один watch dw.repo.modelList<Booking> с backendFilter — realtime и пагинация идут в комплекте.',
    ],
  );
```

Правила по полям:

- **`id`** — `<папка-фичи>/<осмысленное-имя>`. Это **контракт**: по нему на фичу ссылаются Studio, фидбек и тикеты. Переехала папка — id остаётся. Нужно другое имя — заводи новый id и выводи старый из обращения, но **не переименовывай на месте**.
- **`title`** — как фичу называют вслух.
- **`purpose`** — зачем она пользователю. **Опционально и часто не нужно:** у карточки или строки списка своей цели нет, она служит экрану; повторять цель экрана на каждой его части — шум.
- **`behaviors`** — что фича наблюдаемо делает, по одному проверяемому утверждению на пункт. **Критерий, который держит поле живым: каждый пункт можно проверить, посмотрев на работающее приложение.** Как только появляется «хорошо работает с длинными названиями» — поле снова превратилось в сочинение.
- **`requirements`** — что фича обязана соблюдать, наложенное **извне** (только авторизованным, цена не показывается до подтверждения, работает офлайн). Если формулируется как наблюдаемое действие — это `behaviors`.
- **`implementationNotes`** — решения, которые иначе будут переоткрывать («почему превью в строке, а полная картинка в списке»). Пишется для команды, не для клиента: Studio показывает их на технической стороне.

Паспорт нужен виджету-фиче. Если entry point — extension или функция (`context.showInviteDialog()`), вешать спеку не на что, и чекер такую фичу не трогает.

## Пример entry point

```dart
// todo_list_page.dart
class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(todoSearchStringProvider);
    final todos = ref.watch(dw.repo.modelList<Todo>());

    return Scaffold(
      body: todos.dwBuildListAsync(
        loadingItemsCount: 5,
        // локальная фильтрация — обычный .where в виджете; «фреймворочного»
        // способа нет специально (см. dartway-data-layer §3)
        childBuilder: (list) => ListView(
          children: [
            for (final todo in list.where(
              (t) => search == null || t.title.contains(search),
            ))
              TodoItem(todo: todo),
          ],
        ),
      ),
      // `dw.action(...)` возвращает DwUiAction, а не VoidCallback: напрямую в
      // onPressed его не отдать. Под тапом его разворачивает DwActionBuilder —
      // он же гасит повторные тапы и отдаёт busy.
      floatingActionButton: DwActionBuilder(
        action: dw.action((_) async {
          await dw.repo.saveModel(
            Todo(title: 'New task', isCompleted: false, createdAt: DateTime.now()),
          );
        }),
        builder: (context, onPressed, busy) => FloatingActionButton(
          onPressed: onPressed, // null, пока действие бежит
          child: busy
              ? const CircularProgressIndicator()
              : const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

Ключевое: списки `AsyncValue` — через `dwBuildListAsync` (с `loadingItemsCount`); локальный поиск/фильтр — `.where` в виджете (+ провайдер под строку поиска); действия из UI — в `dw.action` (колбэк получает `context`; `(_)`, если не нужен — см. `dartway-data-layer` §4).
