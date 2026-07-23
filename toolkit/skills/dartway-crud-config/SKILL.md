---
name: dartway-crud-config
description: >-
  Серверный playbook DartWay/Serverpod: как писать CRUD-конфиги — DwCrudConfig<T> (одна на
  модель), DwGetModelConfig, DwGetModelListConfig (оба требуют accessFilter), DwSaveConfig
  (allowSave/validateSave/beforeSaveTransaction/afterSaveTransaction/afterSaveTransform/
  afterSaveSideEffects), DwDeleteConfig (allowDelete/afterDelete), DwModelWrapper,
  Event-модели, границы domain(чистое)/app(session-aware). Вся серверная логика идёт через
  конфиги, не через эндпоинты. Использовать при добавлении/изменении серверной логики, прав,
  валидаций, сайд-эффектов для модели.
---

# DartWay — CRUD-конфиги (сервер)

В DartWay **вся серверная логика идёт через CRUD-конфиги**, не через произвольные эндпоинты. Это даёт консистентность и предсказуемость. Конфиги — обёртки (`DwSaveConfig`, `DwDeleteConfig`, `DwGetModelConfig`, `DwGetModelListConfig`) с колбэками для прав, валидации, обработки и сайд-эффектов. См. также `__SERVER_PKG__/CLAUDE.md`.

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

## accessFilter — сердце secure-by-default

У обоих read-конфигов `accessFilter` — **обязательный** параметр: `(Session session) => Future<Expression?>`. Он возвращает SQL-условие, сужающее выборку под текущего пользователя, или `null` — «ограничений нет».

Именно поэтому доступ нельзя забыть закрыть: нет конфига → модель не отдаётся вообще; есть конфиг → фильтр написан явно. `null` — это осознанное «видно всем залогиненным», а не умолчание.

```dart
/// Клиенты видят только свои записи, персонал — все.
Future<Expression<dynamic>?> _bookingAccessFilter(Session session) async {
  if (await session.isStaffMember) {
    return null; // ограничений нет
  }
  final userProfileId = await session.currentUserProfileId;
  return SessionBooking.t.clientProfileId.equals(userProfileId ?? -1);
}
```

Id текущего пользователя — `await session.currentUserProfileId` (не `session.userId`).

## DwGetModelConfig — одна сущность по фильтру

Параметры: `accessFilter` (**required**), `filterPrototype` (**required** — под какие запросы применяется), `createIfMissing` `(session, filter) => model`, `include` (eager-загрузка связей), `defaultOrderByList`. Можно несколько конфигов на модель — разные фильтры или разные права.

На сервере прототип строится специальными конструкторами: `DwBackendFilter.equalsPrototype(fieldName: ...)`, `.andPrototype(children: [...])`, `.orPrototype(children: [...])`. Голого `DwBackendFilter(...)` нет — конструктор приватный.

Прототип описывает **форму** запроса (по какому полю и как сравниваем), а не значение: под него матчатся конкретные фильтры с клиента. На клиентской стороне фильтры не конструируются руками — там enum с `DwBackendFiltersMixin` и его `.equals()` / `.greaterThan()` (контракт — `dartway-data-layer`):

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();
}

// в data-layer: AppBackendFilters.clientProfileId.equals(userProfileId)
```

```dart
final userProfileGetConfig = DwGetModelConfig<UserProfile>(
  accessFilter: (session) async => null,
  filterPrototype: DwBackendFilter.equalsPrototype(fieldName: 'id'),
  include: UserProfile.include(address: Address.include()),
);
```

## DwGetModelListConfig — список

Параметры: `accessFilter` (**required**), `include`, `defaultOrderByList`.

```dart
final clubSessionListConfig = DwGetModelListConfig<ClubSession>(
  accessFilter: (session) async => null,
  include: ClubSession.include(service: ClubService.include()),
  defaultOrderByList: [
    Order(column: ClubSession.t.startsAt, orderDescending: false),
  ],
);
```

## DwSaveConfig — create + update (унифицировано)

**Все хуки имеют одну сигнатуру:** `(Session session, DwSaveContext<T> saveContext)`. Никаких `(initial, updated)` — и то и другое лежит в контексте.

`DwSaveContext<T>`: `currentModel` (модель на текущем шаге — её и правь), `initialModel` (что было в БД, null при insert), `isInsert`, `currentUserId`, `transaction`, `beforeUpdates`/`afterUpdates` (списки `DwModelWrapper` для клиента), `extras` (протащить данные между шагами).

Порядок выполнения и сигнатуры:

1. `allowSave` → `Future<bool>` — права, **обязателен**
2. `validateSave` → `Future<String?>` — текст ошибки или null
3. **открывается транзакция:** `beforeSaveTransaction` → `Future<String?>` → insert/update → `afterSaveTransaction` → `Future<String?>`
4. вне транзакции: `afterSaveTransform` → `Future<void>` (обогащение), затем `afterSaveSideEffects` → `Future<void>` (неблокирующе)

**Оба хука в транзакции возвращают `String?` — как `validateSave`.** Вернул текст → save отклоняется, транзакция откатывается, текст доходит до клиента; вернул `null` → идём дальше. Это и есть способ отказать по правилу, которое видно только внутри транзакции.

**Зачем это, а не `validateSave`:** шаги 1–2 идут ДО транзакции, поэтому правило, стерегущее общий счётчик (места, остатки, лимиты), там гоняется — два параллельных сохранения оба получат «да». Проверяй такое правило в `beforeSaveTransaction`, взяв в той же транзакции **лок на строку**: `findById(..., transaction:, lockMode: LockMode.forUpdate)` — один вызов и лочит строку (`SELECT ... FOR UPDATE`), и возвращает её. `validateSave` проверяет модель, `beforeSaveTransaction` — мир вокруг неё.

**Если правило зависит от текущего состояния самой строки** (роли, флаги согласий, баланс, признак удаления) — включи `lockInitialModelForUpdate: true`. Тогда на **апдейте** исходная модель перечитывается под `FOR UPDATE` внутри транзакции, и шаги 1–2 гоняются уже против неё: параллельное сохранение той же строки ждёт и перевалидируется против того, что реально закоммитили, вместо того чтобы пройти по устаревшему до-состоянию. Флаг опционален (по умолчанию `false`, цикл не меняется) и на insert не влияет — там ещё нечего лочить.

```dart
beforeSaveTransaction: (session, saveContext) async {
  if (!saveContext.isInsert) return null;
  // Лочим и читаем занятие одним вызовом — конкурентные брони
  // сериализуются на этой строке, продать сверх мест нельзя.
  final clubSession = await ClubSession.db.findById(
    session,
    saveContext.currentModel.clubSessionId,
    transaction: saveContext.transaction,
    lockMode: LockMode.forUpdate,
  );
  if (clubSession == null) return 'Session not found';

  final taken = await SessionBooking.db.count(
    session,
    where: (t) => t.clubSessionId.equals(clubSession.id!) &
        t.status.equals(BookingStatus.booked),
    transaction: saveContext.transaction,
  );
  if (taken >= clubSession.capacity) return 'No spots left';
  return null;
},
```

```dart
final clubSessionSaveConfig = DwSaveConfig<ClubSession>(
  allowSave: (session, saveContext) async => session.isStaffMember,
  validateSave: (session, saveContext) async {
    final clubSession = saveContext.currentModel;
    if (clubSession.capacity < 1) {
      return 'Capacity must be at least 1';
    }
    if (saveContext.isInsert && clubSession.startsAt.isBefore(DateTime.now())) {
      return 'Session cannot start in the past';
    }
    return null; // модель в порядке — пускаем
  },
  beforeSaveTransaction: (session, saveContext) async {
    saveContext.currentModel = saveContext.currentModel.copyWith(
      capacity: saveContext.currentModel.capacity.clamp(1, 100),
    );
    return null; // претензий нет — иначе вернули бы текст ошибки
  },
  afterSaveSideEffects: (session, saveContext) async {
    await AppNotifications.sendSessionUpdated(session, saveContext.currentModel);
  },
);
```

Модель правится через `saveContext.currentModel`; связанные обновления для клиента кладутся в `saveContext.beforeUpdates` / `saveContext.afterUpdates`. Транзакционные хуки обязаны завершиться `return null`, если не отклоняют, — иначе analyzer поймает `body_might_complete_normally_nullable`.

## DwDeleteConfig — удаление

Параметры: `allowDelete` `(session, model) => bool` (без него → `notConfigured`), `afterDelete` `(session, model) => [related]`. Если модель не найдена → ok с предупреждением. `DatabaseException` (например, FK) → ошибка.

**Важное ограничение:** у `DwDeleteConfig` нет ни before-хука, ни транзакции — `afterDelete` бежит **после** того, как строка уже удалена, без хендла транзакции. Гоночно-чувствительный пересчёт (освободить место, вернуть остаток на склад) здесь сделать нельзя. Если удаление должно атомарно менять общий счётчик — не удаляй строку, а делай **мягкое удаление статусом** через `DwSaveConfig` (`status: cancelled`): там есть транзакция и `beforeSaveTransaction` с локом. Пример — отмена записи на занятие.

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
