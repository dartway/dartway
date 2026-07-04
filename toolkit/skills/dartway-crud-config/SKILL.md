---
name: dartway-crud-config
description: >-
  Серверный playbook DartWay/Serverpod: как писать CRUD-конфиги — DwCrudConfig<T> (одна на
  модель), DwGetModelConfig, DwGetListConfig, DwSaveConfig (allowSave/validateSave/beforeSave/
  afterSave/afterSaveSideEffects), DwDeleteConfig (allowDelete/afterDelete), DwModelWrapper,
  Event-модели, границы domain(чистое)/app(session-aware). Вся серверная логика идёт через
  конфиги, не через эндпоинты. Использовать при добавлении/изменении серверной логики, прав,
  валидаций, сайд-эффектов для модели.
---

# DartWay — CRUD-конфиги (сервер)

В DartWay **вся серверная логика идёт через CRUD-конфиги**, не через произвольные эндпоинты. Это даёт консистентность и предсказуемость. Конфиги — обёртки (`DwSaveConfig`, `DwDeleteConfig`, `DwGetModelConfig`, `DwGetListConfig`) с колбэками для прав, валидации, обработки и сайд-эффектов. См. также `__SERVER_PKG__/CLAUDE.md`.

## DwCrudConfig<T> — точка входа на модель

Одна `DwCrudConfig<T>` на модель агрегирует все правила — это место, куда смотрят и разработчик, и AI.

```dart
final userProfileCrudConfig = DwCrudConfig<UserProfile>(
  table: UserProfile.t,
  getModelConfigs: [ ... ],   // можно несколько
  getListConfig: ...,
  saveConfig: ...,
  deleteConfig: ...,
);
```

Не забудь зарегистрировать конфиг в `crudConfigurations` при `DwCore.init`. Если конфиг отсутствует → API вернёт `DwApiResponse.notConfigured`.

## DwGetModelConfig — одна сущность по фильтру

Параметры: `filterPrototype` (под какие запросы применяется), `include` (eager-загрузка связей), `additionalEntitiesFetchFunction` `(session, model) => [related]`, `createIfMissing` `(session, filter) => model`. Можно несколько конфигов на модель (разные права/проекции — например, публичные vs приватные поля).

```dart
final userProfileGetConfig = DwGetModelConfig<UserProfile>(
  filterPrototype: DwBackendFilter(field: 'id'),
  include: UserProfile.include(address: Address.include()),
  additionalEntitiesFetchFunction: (session, model) async =>
      session.db.find<BalanceEvent>(where: (t) => t.userProfileId.equals(model.id)),
  createIfMissing: (session, filter) async =>
      UserProfile(id: filter.value as int, name: 'Guest User'),
);
```

## DwGetListConfig — список

Параметры: `include`, `defaultOrderByList`, `additionalModelsFetchFunction` `(session, models) => [related]`.

```dart
final userProfileListConfig = DwGetListConfig<UserProfile>(
  include: UserProfile.include(address: Address.include()),
  defaultOrderByList: [UserProfile.t.createdAt.desc()],
  additionalModelsFetchFunction: (session, models) async =>
      session.db.find<BalanceEvent>(
        where: (t) => t.userProfileId.inSet(models.map((u) => u.id)),
      ),
);
```

## DwSaveConfig — create + update (унифицировано)

Порядок выполнения: `allowSave` (права, обязателен) → `validateSave` (вернуть строку-ошибку или null) → транзакция: `beforeSave` (пре-обработка, модифицирует модель) → insert/update → `afterSave` (доп. апдейты) → вне транзакции: `afterSaveSideEffects` (нотификации, фон).

```dart
final userProfileSaveConfig = DwSaveConfig<UserProfile>(
  allowSave: (session, initial, updated) async {
    final exists = await session.db.findFirstRow<UserProfile>(
      where: (t) => t.email.equals(updated.email) & t.id.notEquals(updated.id),
    );
    return exists == null;
  },
  validateSave: (session, initial, updated) async =>
      updated.email.isEmpty ? 'Email cannot be empty' : null,
  beforeSave: (session, transaction, initial, updated) async =>
      DwPreSaveResult(model: updated.copyWith(name: updated.name.trim())),
  afterSave: (session, transaction, initial, saved, {beforeUpdates}) async {
    final events = await session.db.find<BalanceEvent>(
      where: (t) => t.userProfileId.equals(saved.id),
    );
    return events.map((e) => DwModelWrapper(object: e)).toList();
  },
  afterSaveSideEffects: (session, initial, saved, {beforeUpdates, afterUpdates}) async {
    await AppNotifications.sendProfileUpdated(session, saved);
  },
);
```

## DwDeleteConfig — удаление

Параметры: `allowDelete` `(session, model) => bool` (без него → `notConfigured`), `afterDelete` `(session, model) => [related]`. Если модель не найдена → ok с предупреждением. `DatabaseException` (например, FK) → ошибка.

```dart
final userProfileDeleteConfig = DwDeleteConfig<UserProfile>(
  allowDelete: (session, model) async => model.balance <= 0,
  afterDelete: (session, model) async => session.db.find<BalanceEvent>(
    where: (t) => t.userProfileId.equals(model.id),
  ),
);
```

## Где какая логика

- **Конфиги держи маленькими** — только права, проверки, обработка, сайд-эффекты.
- **Чистая логика** (вычисления из полей, без Session/IO) → `/domain` (extensions на моделях).
- **Workflow** (session-aware: внешние API, оркестрация) → `/app`.
- **Транзакционные/денежные потоки** → Event-модели (`BalanceEvent`) вместо прямого апдейта поля: безопасность от гонок, аудит, единое место правил.
- Все апдейты в ответах оборачивай в `DwModelWrapper`.

## Custom endpoint — крайний случай

Только когда не ложится в CRUD (file upload/download — часто всё равно как модель `FileUploadRequest`, webhooks, тяжёлая async-обработка). Документировать как исключение.

## Workflow и тесты

Модель в `/models` → `serverpod generate` → `create-migration` → `DwCrudConfig` в `/crud` → логика в `/domain` или `/app` → тесты. Юнит-тесты на каждый конфиг (права, валидация, pre/post, sideEffects) и Event-модели. Багфикс — сначала падающий тест на причину.
