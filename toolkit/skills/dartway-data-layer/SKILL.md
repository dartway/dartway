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

## 4a. Производное состояние — провайдер, а не сборка в виджете

Состояние, выведенное **из нескольких источников** или содержащее правило, живёт в провайдере
(`@riverpod`), а не собирается в `build`.

```dart
// ❌ виджет вручную сшивает три watch и подаёт их в функцию — пересчёт на каждой сборке
final state = resolveSomething(
  a: ref.watch(providerA), b: ref.watchUserProfile.flag, c: ref.watch(providerC),
);

// ✅ провайдер знает, откуда данные; чистая функция — что из них следует
final state = ref.watch(somethingProvider(id: id));
```

**Пишем провайдер руками, без `riverpod_generator`** (см. политику кодогена в `CLAUDE.md`):

```dart
final courseLockStateProvider =
    Provider.family<CourseLockState, ({int? courseId, int accessCourseId})>(
  (ref, args) => CourseLockState.resolve(
    userCourse: ref.watchUserCourseById(args.accessCourseId),
    hidePaidFeaturesInfo: ref.watchUserProfile.hidePaidFeaturesInfo,
    now: DateTime.now(),
  ),
);
```

**Семейный нотифаер тоже пишется руками.** `NotifierProvider.family` объявлен как
`NotifierT Function(ArgT arg)` — аргумент приходит в фабрику, нотифаер принимает его конструктором:

```dart
class AudioControllerNotifier extends Notifier<AsyncValue<AudioControllerState>> {
  AudioControllerNotifier(this._args);
  final AudioControllerArgs _args;
  @override
  AsyncValue<AudioControllerState> build() { /* ... _args.mediaId ... */ }
}

final audioControllerProvider = NotifierProvider.family<
    AudioControllerNotifier, AsyncValue<AudioControllerState>, AudioControllerArgs>(
  AudioControllerNotifier.new,
);
```

Так устроен и сам фреймворк (`DwModelListState(this.config)`). Внутренний `ref.$arg`, которым
пользуется кодоген, рукописному классу не нужен — и трогать его нельзя, он `@internal`.

**Ключ семейства — значение со значимым равенством.** Модели Serverpod сравниваются по identity:
семейство по модели создаёт новый провайдер на каждой сборке, с пересчётом и авто-диспозом впустую.
Ключ — идентификаторы или **рекорд** из них: у рекорда равенство по значению из коробки, поэтому
ручной вариант здесь не проигрывает генератору, а выигрывает — без ожидания `build_runner`.

**Провайдер не лезет во внутренности чужой фичи.** Расширения доступа к данным обычно объявлены на
`WidgetRef`, а внутри провайдера доступен `Ref` — соблазн импортировать `logic/` соседней фичи
велик и ловится только чекером. Правильный ход: **публичный файл той фичи даёт расширение на `Ref`**.

**Не заводи локальное состояние поверх серверного.** Запись через `dw.repo` обновляет списки сама:
«уже отправленные заявки» не нужно копить в `Set<int>` — ответ уже есть в списке, который экран и так
watch-ит. Локальная копия серверной правды — второй источник, который может только разъехаться с первым.

**Не заводи шимы над API фреймворка.** `ref.saveModel(...)`, пробрасывающий вызов в
`dw.repo.saveModel(...)`, ничего не добавляет, но прячет настоящий API: на боевом проекте на такой
прослойке жили 82 вызова, и половина команды не знала, что вызывает.

### Подмена провайдера в тесте

У **ручного** `NotifierProvider` нет `overrideWithValue` — этот метод есть только у провайдеров
значения. Подменяется фабрика: наследник, который переопределяет `build()` готовым значением.

```dart
// ❌ не компилируется: overrideWithValue не определён для NotifierProvider
overrides: [userCoursesStateProvider.overrideWithValue(userCourses)],

// ✅ фейк-нотифаер: тест проверяет расширение над состоянием, а не его загрузку
class _FixedUserCoursesState extends UserCoursesState {
  _FixedUserCoursesState(this.fixedCourses);
  final List<UserCourse> fixedCourses;
  @override
  List<UserCourse> build() => fixedCourses;
}

overrides: [
  userCoursesStateProvider.overrideWith(() => _FixedUserCoursesState(userCourses)),
],
```

**У семейства `overrideWith` принимает беспараметрную фабрику** — `() => notifier`, а не
`(arg) => notifier`, хотя сам `NotifierProvider.family` объявлен как `NotifierT Function(ArgT)`.
Подменяется всё семейство сразу, поэтому аргумент фейку отдаёшь сам через конструктор:

```dart
final fake = FakeAudioControllerNotifier(
  const AudioControllerArgs(246, 'https://example.com/podcast.mp3'),
);
overrides: [audioControllerProvider.overrideWith(() => fake)],
```

Наследник семейного нотифаера обязан **пробросить аргумент в `super`** и переопределить
беспараметрный `build()` — тот, что принимал аргументы, остался в кодогенном мире:

```dart
class FakeAudioControllerNotifier extends AudioControllerNotifier {
  FakeAudioControllerNotifier(AudioControllerArgs args) : super(args);
  @override
  AsyncValue<AudioControllerState> build() => const AsyncValue.loading();
}
```

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
final me = ref.watch(dw.repo.model<UserProfile>(...));

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

## 8. Real-time между пользователями — `broadcastTo` в конфиге

**Чего НЕТ по умолчанию:** `saveModel` возвращает обновление **только тому, кто сохранял**. Поэтому «клиент А записался — у клиента Б обновилось само» само по себе не работает: `dw.repo.modelList` реактивен к *своим* правкам.

**Включается одной строкой — на сервере, в CRUD-конфиге.** Ничего писать во Flutter не надо: приложение уже подписано на публичный канал в своём корне.

```dart
// СЕРВЕР — в конфиге модели:
saveConfig: DwSaveConfig<NewsPost>(
  allowSave: ...,
  broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],
),
deleteConfig: DwDeleteConfig<NewsPost>(
  allowDelete: ...,
  // без этого у остальных останется висеть удалённая строка
  broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
),
```

Пришедшая в канал модель роутится по типу в **любой** `dw.repo.modelList<T>()` у подписчиков — список перерисовывается сам, без кода обновления на обеих сторонах.

**Канал — это аудитория, и фреймворк не может проверить, кто в ней.** Улетает всё, что затронуло сохранение, каждому подписчику — независимо от того, показал бы ему эту строку `accessFilter` или нет. Отсюда два правила:

- `broadcastTo` — **только для моделей, публичных целиком** (каталог, цены, остатки, опубликованные новости). Их `accessFilter` и так открыт всей аудитории;
- для строк, принадлежащих одному человеку (заказы, сообщения, профили), — **не вещать**, а уведомлять владельца: `session.sendUpdatesToUser(id, updatedModels: [...])`.

**Когда надо выбрать, что именно улетит** (сохраняется приватная строка, а публично поменялся счётчик) — императивный вызов в `afterSaveSideEffects`:

```dart
// летит только публичное занятие, сама бронь остаётся приватной
session.sendUpdates(
  channels: [DwCoreConst.publicUpdatesChannel],
  updatedModels: [updatedSession],
);
```

Канал можно сузить до нужной аудитории и построить из контекста — `['chat:${ctx.currentModel.chatId}']`. Тогда экран подписывается на него точечно:

```dart
DwChannelSubscriptionWidget(channel: 'chat:$chatId', child: messagesList)
```

### Какой канал слушать и куда слать — это и есть решение

Канал — **широковещательная шина**: **всё**, что в него постят, прилетает **каждому** подписчику. Поэтому канал **скоупь под аудиторию, которой обновление реально нужно**. Вопрос всегда один: «кто по праву должен увидеть это изменение?» — и шли/подписывай ровно им.

| Аудитория обновления | Канал |
|---|---|
| Публичное для всех (каталог, цены, остатки, новости) | `DwCoreConst.publicUpdatesChannel` — приложение подписано на него в корне |
| Группа (чат-комната, доска) | канал с ключом группы: `'chat:$channelId'` — подписка на экране группы |
| Приватное одному юзеру (его бронь отменили) | `session.sendUpdatesToUser(userId, ...)` — его личный канал, подписка не нужна |

**Анти-паттерн — слать в общий канал всё подряд.** Опасен не сам общий канал (он и нужен для публичного), а то, что в него кладут: если туда уедет приватная строка, её получит каждый подписчик — `accessFilter` тут уже не работает, он про чтение через API. Проверка перед тем, как поставить `broadcastTo` с публичным каналом: **«эту строку и так вправе прочитать любой пользователь?»** Нет — значит канал уже, либо `sendUpdatesToUser`.

Второй частый промах — вешать `broadcastTo` на конфиг приватной модели ради публичного побочного эффекта (сохраняем бронь, а показать надо счётчик мест). `broadcastTo` шлёт **всё, что затронуло сохранение**, включая саму бронь. В таком случае — императивный `session.sendUpdates(channels: [...], updatedModels: [публичнаяМодель])`, где ты выбираешь, что улетит.

Правило: **скоуп канала = ровно те, кому это изменение по праву видно.**

---

## 9. Файлы и картинки — `DwFileUploadHandler`

**Зачем:** выбор файла, заливка в хранилище и получение публичной ссылки — один вызов. Своего пикера, своего http-клиента и своего эндпоинта писать не нужно.

```dart
// ✅ весь аплоад целиком: пикер → хранилище → публичный URL
final imageUrl = await DwFileUploadHandler.pickAndUploadImageUrl();
if (imageUrl == null) return;              // null = пользователь закрыл пикер, это не ошибка
await dw.repo.saveModel(userProfile.copyWith(imageUrl: imageUrl));
```

Дальше ссылка живёт как обычное поле модели и едет тем же CRUD-путём, что остальные — отдельного «файлового» слоя в приложении нет.

Соседние формы: `pickAndUploadImage()` (вернёт `DwCloudFile` с размером и mime), `uploadXFileToServer(xFile:)` — когда файл уже получен (камера, drag-n-drop).

**Оберни в `dw.action`** — заливка долгая, и `DwActionBuilder` сам погасит повторный тап и отдаст `busy` для индикатора.

**Что нужно на сервере:** `cloudStorageConfig` в `DwCore.init` (в проекте это ключи `dwCloudStorage*` в `config/passwords.yaml`, а в разработке — сервис `minio` из `docker-compose.yaml`). Если хранилище не настроено, загрузка честно скажет об этом, а не упадёт молча.

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
- [ ] Обновление должен увидеть **другой** пользователь? `dw.repo.modelList` сам этого не делает — `broadcastTo` в конфиге (публичное), канал с id группы (групповое), `sendUpdatesToUser` (приватное).
- [ ] Ставишь `broadcastTo` с публичным каналом — ответил себе «эту строку вправе прочитать любой»? Если нет — канал уже или `sendUpdatesToUser`.
