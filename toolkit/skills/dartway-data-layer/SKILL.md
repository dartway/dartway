---
name: dartway-data-layer
description: >-
  DartWay Flutter data-layer и specials (проекты DartWay): доступ к данным только
  через dw.repo — чтение как провайдеры под родной ref.watch/read/refresh
  (dw.repo.model/maybeModel/modelList), запись dw.repo.saveModel/deleteModel
  (никаких репозиториев и ручной синхронизации), списки через dwBuildListAsync(loadingItemsCount:),
  сужение запросом через backendFilter, локальную фильтрацию делай сам .where в виджете,
  действия из UI через dw.action (единая обработка ошибок/loading), уведомления через dw.notify.* (не SnackBar),
  профиль через ref.watchUserProfile/readUserProfile (геттеры, не CRUD), выход через
  sessionProvider.notifier.signOut(). Использовать при работе с данными, действиями, уведомлениями,
  загрузкой/сохранением моделей во Flutter-фичах.
---

# DartWay — data-layer и specials (Flutter)

Во Flutter DartWay **доступ к данным и побочные действия идут через готовый data-layer**, а не через репозитории, ручные `Future`/`setState` и сырые попапы. Это даёт единообразную обработку ошибок, loading и реактивность. Источник правил чистоты — `dartway-clean-code`; карта слоёв — `__FLUTTER_PKG__/CLAUDE.md`.

> ⚠️ API ниже сверен с кодовой базой. Чтение — провайдеры под `ref.watch(dw.repo.…)`, **не** `ref.watchModel`. `DwCallback` **не существует** — это `DwUiAction`. `watchUserProfile` — **геттер** (без скобок).

---

## 1. Доступ к данным — только через `dw.repo`

**Зачем:** одна точка данных на все фичи. Чтение — риверпод-провайдеры, которые ты потребляешь **родным** `ref`: `ref.watch` — реактивная подписка (UI перестраивается), `ref.read(...future)` — разовое чтение, `ref.refresh(...future)` — принудительный свежий фетч. Запись — методы. Конфиг чтения/записи задаётся на сервере (`DwCrudConfig`), фронту репозитории не нужны.

```dart
// ❌ свой репозиторий / ручной фьючер / прямой клиент
final repo = ChatRepository();
final posts = await repo.fetchPosts();

// ✅ dw.repo — единая точка данных
final coursesAsync = ref.watch(dw.repo.modelList<LearningCourse>());         // реактивный список
final course       = ref.watch(dw.repo.model<LearningCourse>(filter: ...));  // AsyncValue<T>, нет → StateError
final maybe        = ref.watch(dw.repo.maybeModel<UserCourse>(filter: ...)); // AsyncValue<T?>, null вместо ошибки
final once         = await ref.read(dw.repo.model<LearningCourse>(id: 1).future); // разовое чтение
await dw.repo.saveModel(updatedCourse);                                      // create+update (один save)
await dw.repo.deleteModel(post);
```

**Чтение — провайдеры `dw.repo.model/maybeModel/modelList` под родным `ref`; запись — методы `dw.repo.saveModel/deleteModel`.** Никаких `ref.watchModel` и `DwRepository.` — единственная точка доступа к данным это `dw.repo`. `model` бросает `StateError`, если модели нет; `maybeModel` возвращает `null`. Принудительный фетч — `ref.refresh(dw.repo.maybeModel(...).future)` (фетчащий провайдер). **Create и Update — это один `saveModel`** (закон CRUD).

## 2. Списки — через `dwBuildListAsync`

**Зачем:** единый рендер `AsyncValue<List<T>>` со скелетонами на loading и обработкой ошибок — без россыпи `when(loading/error/data)`.

```dart
// ❌ ручной when с копипастой loading/error в каждой фиче
coursesAsync.when(loading: () => ..., error: (e, _) => ..., data: (list) => ...);

// ✅
coursesAsync.dwBuildListAsync(
  loadingItemsCount: 5,
  childBuilder: (list) => ListView(
    children: [for (final course in list) CourseCard(course: course)],
  ),
);
```

**Заводя новую модель, зарегистрируй её default-инстанс** в `__FLUTTER_PKG__/lib/core/default_models.dart` — по вызову на модель:

```dart
dw.repo.setupRepository(
  defaultModel: ClubSession(id: dw.repo.mockModelId, capacity: 10, ...),
);
```

Скелетон рисуется из твоего же виджета, построенного на этом инстансе, — поэтому он похож на будущий контент, а не на generic-шиммер. Без регистрации первый же `dwBuildListAsync` падает в рантайме: `Default Objects Repository doesn't contain a model of type X`.

## 3. Фильтрация — `backendFilter` (сервер) + `.where` (клиент)

**Зачем:** сузить список запросом к БД — через `backendFilter`. Локальную фильтрацию уже загруженного фреймворк специально **не держит**: это тривиальный `.where`, делай его сам в виджете, не ищи «фреймворочный» способ.

**Фильтр на сервере — `backendFilter:`.** Когда список надо сузить запросом (свои записи, сообщения одного чата, предстоящие занятия). Фильтры — enum с `DwBackendFiltersMixin` и его `.equals()`/`.greaterThan()`:

```dart
enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  startsAt<DateTime>();

  static DwBackendFilter clientBookings(int id) =>
      AppBackendFilters.clientProfileId.equals(id);
}

// в фиче:
ref.watch(dw.repo.modelList<SessionBooking>(
  backendFilter: AppBackendFilters.clientBookings(ref.watchUserProfile.id!),
));
```

`DwGetModelListConfig` на сервере **не требует** `filterPrototype` (в отличие от `DwGetModelConfig` для одной модели) — списочные backend-фильтры работают без регистрации прототипа. Секьюрити — на `accessFilter` конфига (сервер), не на клиентском сужении.

**Локальный фильтр/поиск — сам `.where` в виджете.** Строку поиска держи в Riverpod-провайдере, фильтруй уже загруженный список прямо в билдере:

```dart
final query = ref.watch(searchQueryProvider);
coursesAsync.dwBuildListAsync(
  childBuilder: (list) {
    final visible = list.where((c) => c.title.contains(query)).toList();
    return ListView(children: [for (final c in visible) CourseCard(course: c)]);
  },
);
```

## 4. Действия из UI — `dw.action`

**Зачем:** единая обёртка для действий пользователя (нажатия, сабмиты): автоматический loading-стейт, обработка ошибок (с репортом в алертинг — см. `label`), подтверждения. Колбэк получает `BuildContext`. Не оборачивай в сырой `() async {}`/`onPressed`.

```dart
// ❌ сырой обработчик: ошибки и loading руками в каждом виджете
onPressed: () async { await doSomething(); }

// ❌ ручной confirm-диалог внутри действия (боль легаси-проектов)
final confirm = await showDialog<bool>(...); if (confirm != true) return;

// ✅ dw.action — context, типизированный результат, встроенный confirm
final deleteAction = dw.action<bool>(
  (context) async {
    await dw.repo.deleteModel(post);
    return true;
  },
  label: 'deletePost', // имя действия в error-репортах/алертах
  confirmation: DwUiConfirmation('Delete this post?', isDestructive: true),
);
// в виджете: onTap: deleteAction   (или dw.action((_) async {...}) если context не нужен)
```

> Реальное имя — **`DwUiAction`** (46+ использований). `DwCallback` в проекте нет.
> Отказ в confirm-диалоге отменяет действие целиком (без нотификаций и follow-up). Кастомный диалог — `DwConfig.confirmDialogBuilder`. Ошибки действий автоматически попадают в алертинг с контекстом (роут, фичи экрана, `label`) — см. доку error-reporting фреймворка.

## 5. Уведомления — `dw.notify.*` (не `SnackBar`)

**Зачем:** единый стиль тостов/нотификаций по всему приложению. Не дёргай `ScaffoldMessenger`/`SnackBar`/кастомные попапы.

```dart
// ❌
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Готово')));

// ✅
dw.notify.success('Сохранено');
dw.notify.error('Файл слишком большой');
dw.notify.warning('Проверьте поля');
dw.notify.info('Загрузка началась');
```

## 6. Профиль пользователя — `ref.watchUserProfile` (геттер, не CRUD)

**Зачем:** текущий профиль — это специальный источник, не обычная модель. Не тяни его через `watchModel<UserProfile>()`.

```dart
// ❌ профиль через обычный CRUD
final me = ref.watchModel<UserProfile>(filter: ...);

// ✅ специальные геттеры (без скобок!) — возвращают UserProfile напрямую
final isMine = post.authorProfileId == ref.watchUserProfile.id;   // реактивно
final myId   = ref.readUserProfile.id;                            // разово
```

## 7. Выход — через `sessionProvider`

**Зачем:** завершение сессии — централизованная операция dartway-сессии, не самописный сброс стейта.

```dart
// ✅ как в кодовой базе
ref.read(dw.sessionProvider!.notifier).signOut();
```

## 8. Real-time между пользователями — именованный канал (простой рецепт, но выбор канала важен)

**Чего НЕТ из коробки:** `saveModel` возвращает обновление **только тому, кто сохранял**. Каждый клиент по умолчанию слушает лишь свой личный канал. Поэтому «клиент А записался — у клиента Б обновилось само» **не работает автоматически**: `watchModelList` реактивен к *своим* правкам, чужие не вещает.

**Рецепт — именованный канал, обе стороны** (это всё, тут нечего долго изучать):

```dart
// СЕРВЕР — в хуке CRUD-конфига (напр. afterSaveTransaction), после пересчёта:
await session.messages.postMessage(
  scheduleAvailabilityChannel,               // имя канала — общая константа
  DwUpdatesTransport(
    wrappedModelUpdates: [DwModelWrapper(object: updatedSession)],
  ),
);
```

```dart
// FLUTTER — оберни экран в подписку на тот же канал:
DwChannelSubscriptionWidget(
  channel: scheduleAvailabilityChannel,
  child: scheduleList,   // внутри — обычный ref.watchModelList<ClubSession>()
)
```

Пришедшая в канал модель роутится по типу в **любой** `watchModelList<T>()` у подписчиков — список перерисовывается сам, без кода обновления. Имя канала держи **общей константой** (один файл, импортят и сервер, и Flutter), чтобы стороны не разъехались.

### Какой канал слушать и куда слать — это и есть решение

Канал — **широковещательная шина**: **всё**, что в него постят, прилетает **каждому** подписчику. Поэтому канал **скоупь под аудиторию, которой обновление реально нужно**. Вопрос всегда один: «кто по праву должен увидеть это изменение?» — и шли/подписывай ровно им.

| Аудитория обновления | Канал |
|---|---|
| Публичное, все на одном экране (свободные места на расписании) | один именованный канал (`scheduleAvailabilityChannel`), все на экране подписаны |
| Группа (чат-комната, доска) | канал с ключом группы: `'chat-$channelId'` — только её участники |
| Приватное одному юзеру (его бронь отменили) | `session.sendUpdatesToUser(userId, updatedModels: [...])` — его личный канал, отдельная подписка не нужна |

**Анти-паттерн — один глобальный канал на все обновления.** Тогда каждому клиенту прилетают **все** изменения во всём приложении: лишний трафик, шум и **утечка приватного** (клиент получает модели, которых видеть не должен). Так — никогда.

Правило: **скоуп канала = ровно те, кому это изменение нужно.** Публичное на экране → общий именованный канал; групповое → канал с id группы; приватное одному → `sendUpdatesToUser`.

---

## Чек-лист data-layer

- [ ] Данные — только `dw.repo`: чтение — провайдеры `dw.repo.model/maybeModel/modelList` под `ref.watch/read/refresh`; запись — `dw.repo.saveModel/deleteModel`. Нет `ref.watchModel`, `DwRepository.`, репозиториев, ручных `Future`, прямого клиента.
- [ ] Create и Update — один `saveModel` (не два разных метода).
- [ ] Списки `AsyncValue` — через `dwBuildListAsync(loadingItemsCount:)`, не россыпь `when`.
- [ ] Сужение запросом — `backendFilter`; локальную фильтрацию делаешь сам `.where` в виджете (фреймворк её не держит).
- [ ] Действия из UI — `dw.action((context) async {...})`, не сырой `onPressed`/`() async {}`.
- [ ] Уведомления — `dw.notify.success/warning/error/info`, не `SnackBar`/`ScaffoldMessenger`.
- [ ] Профиль — `ref.watchUserProfile`/`readUserProfile` (геттеры), не `watchModel<UserProfile>()`.
- [ ] Выход — `ref.read(dw.sessionProvider!.notifier).signOut()`.
- [ ] Обновление должен увидеть **другой** пользователь? `watchModelList` сам этого не делает — именованный канал (`postMessage` + `DwChannelSubscriptionWidget`) для общего, `sendUpdatesToUser` для приватного.
