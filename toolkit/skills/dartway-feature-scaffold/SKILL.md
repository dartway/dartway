---
name: dartway-feature-scaffold
description: >-
  Пошаговый playbook создания новой фичи в DartWay end-to-end (Flutter + Serverpod):
  навигация → UI entry point → state/logic через data-layer и Riverpod → backend CRUD-конфиги
  → модели/БД → тесты. Структура фичи (entry point + widgets + logic), изоляция (импорт только
  entry point), границы domain/app/ui_kit. Использовать при добавлении новой функциональности,
  экрана, флоу или модели.
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

### 3. State & Logic
Определи, какие данные нужны UI. Доступ к данным — только методами data-layer: `watchModel`/`readModel`/`watchMaybeModel`/`readMaybeModel`, `saveModel`, `deleteModel`, `watchModelList`/`readModelList`. Для сложных сценариев/переиспользования внутри фичи — Riverpod-провайдер. Локальный стейт — Riverpod + StatefulWidget + flutter_hooks. Опиши все действия пользователя (create/edit/delete) до привязки к бэкенду.

### 4. Backend (CRUD-конфиги)
Каждое действие пользователя маппится на CRUD-слой — никаких произвольных эндпоинтов. Используй `SaveConfig`/`DeleteConfig`/`GetModelConfig`/`GetListConfig`, ответы оборачивай в `DwModelWrapper`. В конфигах: права, валидации, pre/post-обработка, сайд-эффекты. Детали — скилл `dartway-crud-config`.

### 5. Модели & БД
Уточни модели под реальные нужды фичи: поля и связи (1–1, 1–N, N–N). Поле nullable — только если значение реально может отсутствовать в домене, не ради удобства UI. Схема отражает доменную реальность. После правки YAML — `serverpod generate` + миграция.

### 6. Тесты
Сервер: юнит-тесты на каждый CRUD-конфиг (права, валидации, pre/post, sideEffects), тесты Event-моделей. Флаттер: widget-тест на entry point, provider-тесты на логику, integration — на навигацию и ключевые действия. Порог — по сложности (см. `dartway-clean-code`, Часть 3).

### 7. Завершение (закон №6)
Прогони скилл `dartway-finish`: аудит диффа против контракта, проверка дрейфа дока фичи (`docs/2_features/<FEATURE>.md`) и покрытия тестами. Новую фичу — заведи в `docs/2_features/` с шапкой `code-anchors`. Скилл показывает предложения и применяет только подтверждённое.

## Пример entry point

```dart
// todo_list_page.dart
class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(todoSearchStringProvider);
    final todos = ref.watchModelList<Todo>(
      // frontendFilter — предикат на одну модель (не трансформ списка)
      frontendFilter: (todo) => search == null || todo.title.contains(search),
    );

    return Scaffold(
      body: todos.dwBuildListAsync(
        loadingItemsCount: 5,
        childBuilder: (list) => ListView(
          children: [for (final todo in list) TodoItem(todo: todo)],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: dw.action((_) async {
          await ref.saveModel(
            Todo(title: 'New task', isCompleted: false, createdAt: DateTime.now()),
          );
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Ключевое: списки `AsyncValue` — через `dwBuildListAsync` (с `loadingItemsCount`); локальный поиск/фильтр — `frontendFilter` + провайдер; действия из UI — в `dw.action` (колбэк получает `context`; `(_)`, если не нужен — см. `dartway-data-layer` §4).
