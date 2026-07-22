# DartWay-монорепо — гайд проекта для Claude

Монорепо на стеке **Serverpod + DartWay + Flutter + Riverpod**. DartWay — **highly opinionated** фреймворк: меньше свободы в том, *как* делать → больше консистентности и скорости. Не изобретай альтернативные подходы — следуй принятым паттернам.

> Эта обвязка (методология + скиллы + команды) приезжает из монорепо DartWay (`toolkit/`, ветка `stable`) и ставится в `.claude/` этого репозитория (коммитится). Файлы `CLAUDE.md`, `skills/dartway-*` и команды `commit`/`dartway-audit` — управляемые: не редактируй их здесь, они перезаписываются при обновлении; кастомизация — копией под своим именем. Источник правды — тулкит в монорепо. Структура пакетов детектится автоматически; пути ниже подставлены при установке.

## Структура монорепо

4 Dart-пакета (роль определяется суффиксом имени):

| Пакет | Роль | Что делает |
|---|---|---|
| `__SERVER_PKG__` | server | Serverpod-бэкенд: YAML-модели, CRUD-конфиги, серверная логика и workflow |
| `__CLIENT_PKG__` | client | Сгенерированный Serverpod protocol. **Руками не править** |
| `__SHARED_PKG__` | shared | Чистый Dart, общий для сервера и флаттера: enum'ы, consts, утилиты |
| `__FLUTTER_PKG__` | flutter | Flutter-приложение: фичи, UI Kit, навигация, data-layer |

## Кросс-стековые законы (действуют везде)

1. **CRUD — основа всего.** Все взаимодействия Flutter ↔ Server идут через CRUD-операции над моделями. Никаких произвольных эндпоинтов без крайней необходимости. Create и Update объединены в один `save`.
2. **Domain-first.** Любая фича начинается с модели(ей). Модель отражает доменную реальность, а не сиюминутные нужды UI. Данные живут в моделях — UI это только проекция.
3. **Фича = end-to-end.** Фича — это сквозной поток через сервер (модели + CRUD-конфиги) и флаттер (entry point + widgets + logic). Извне фичи импортируется **только** её entry point.
4. **3 уровня усложнения логики** (по возрастанию «крайности»): Event-модели → конфигурация CRUD (`SaveConfig`/`GetConfig`/...) → custom endpoint (только когда иначе никак, документировать как исключение).
5. **Нейминг.** Классы — минимум 2 слова (`UserProfile`, не `User`). Переменные полностью описательны и совпадают с типом (`userProfile`, `userProfileId`). В полях связей с пользователем всегда слово Profile: `userProfileId`, `authorProfileId`, `updatedByProfileId`. Запрещены `id`/`data`/`info`/`obj`/`temp`/`val`/`item`/`x`.
6. **Завершение = аудит + доки.** Фича не закончена, пока не прогнан `dartway-finish`: аудит диффа против контракта чистоты и обновление документации затронутой фичи (`docs/2_features/<FEATURE>.md`). Доки живут синхронно с кодом — меняешь код фичи, обновляешь её док в той же задаче.

## Документация (`docs/`)

- **`docs/1_general/`** — архитектура и инфраструктура (`FLUTTER_ARCHITECTURE.md`, `SERVER_ARCHITECTURE.md` и т.п.).
- **`docs/2_features/`** — глубокие доки по фичам; шапка с `code-anchors` (пути кода) и `last-verified`. **Перед работой над фичей прочитай её док**; меняешь код фичи — обнови док (закон №6).
- **`docs/audits/`** — отчёты `/dartway-audit`. Продуктовая логика — в `docs/`.

## Чистота и завершение

Для **любого** Dart/Flutter кода действует контракт чистого кода: `.claude/skills/dartway-clean-code/SKILL.md` (8 жёстких правил команды + SOLID/KISS/DRY/YAGNI + тесты для сложного). Это контракт стиля — сверяйся при написании, рефакторинге и ревью.

**Завершение задачи (закон №6):** закончив фичу/задачу, прогоняй `dartway-finish` перед коммитом/PR. Он аудитит дифф против контракта, проверяет дрейф документации фичи и покрытие тестами, **показывает предложения и применяет только подтверждённое**.

## Скиллы и команды

- Скиллы (`.claude/skills/`): `dartway-requirements`, `dartway-plan`, `dartway-clean-code`, `dartway-navigation`, `dartway-feature-scaffold`, `dartway-crud-config`, `dartway-push-delivery`, `dartway-ui-kit`, `dartway-data-layer`, `dartway-models`, `dartway-finish` — подгружаются по релевантности задачи.
- Команды (`.claude/commands/`): `/dartway-audit` — глубокий аудит модуля; `/commit` — коммит в формате CI проекта.

**Жизненный цикл задачи:** `dartway-requirements` (анализ спеки → вопросы → варианты) → `dartway-plan` (пошаговый план + риски) → реализация (слоевые скиллы) → `dartway-finish` (аудит + docs-sync + тесты перед PR).

## Git

PR и диффы — против ветки `__BASE_BRANCH__`. Первая строка коммита: `<type>: <описание на англ.> #<TICKET>` (`type` = `feat`/`fix`/`chore`); тикет передаётся аргументом `/commit`, точный формат проверяет CI проекта.

---

## Сервер (`__SERVER_PKG__`)

**Главный закон:** вся логика — через **CRUD-конфиги**, не через произвольные эндпоинты. Domain-first.

Структура `lib/src/`: `app/` (session-aware workflow) · `crud/` (CRUD-конфиги — здесь вся логика) · `dartway/` (внутренние утилиты) · `domain/` (чистые extensions, без Session/IO/БД) · `endpoints/` (крайний случай: upload, webhooks) · `generated/` (**не редактировать**) · `models/` (YAML-схема) · `web/`. Граница: **domain** — чистые правила, **app** — session-aware сайд-эффекты.

- **Модели:** nullable только если значение реально может отсутствовать в домене. **Base vs Event:** Base — текущее состояние (`UserProfile`), Event — изменения над базой (`BalanceEvent`); для денег/транзакций используй Event (не меняй поле вроде `balance` напрямую). Связи явные в YAML, двунаправленные — одинаковый `relation(name=...)`. Playbook — `dartway-models`.
- **CRUD:** одна `DwCrudConfig<T>` на модель (`allowSave` → `validateSave` → `beforeSave` → запись → `afterSave` → `afterSaveSideEffects`; `getModelConfigs`/`getListConfig`/`deleteConfig`); без конфига API вернёт `notConfigured`; ответы в `DwModelWrapper`. Playbook — `dartway-crud-config`.
- **Push delivery:** универсальная очередь/lease/retry/cleanup живёт в `DwPush`; приложение владеет аудиторией, токенами, preferences и provider SDK. Playbook — `dartway-push-delivery`.
- **Workflow модели:** правка YAML → `serverpod generate` (обновляет `generated` + client-пакет) → `create-migration` → `DwCrudConfig` + регистрация в `crudConfigurations` → миграции на старте → тесты.
- **Auth:** пользователь — **наша** модель `UserProfile`; `serverpod_auth` **не используем** (в свежих версиях у него свой `UserProfile` → конфликт имён). Аутентификация — через DartWay (`DwPhoneAuthConfig` и т.п.).

## Flutter (`__FLUTTER_PKG__`)

Структура `lib/`: `admin/` · `app/` (основные фичи) · `auth/` · `common/` · `core/` (router, dw_core) · `data/` (data-layer) · `domain/` (кросс-фича extensions) · `ui_kit/`.

- **Фичи:** фича = entry point (один публичный файл) + `widgets/` + `logic/`. Извне импортируй **только entry point**. Кросс-фичевая логика — в `lib/domain/`.
- **Данные (data-layer):** только через `watchModel`/`readModel`/`watchMaybeModel`/`readMaybeModel`/`saveModel`/`deleteModel`/`watchModelList`. Списки — `dwBuildListAsync(loadingItemsCount:)`; локальный фильтр — `frontendFilter`. Контракт — `dartway-data-layer`, создание фичи — `dartway-feature-scaffold`.
- **UI Kit — единственный источник стилей:** в `app/`/`auth/`/`common/` запрещены прямые `Color`/`TextStyle`/`BorderRadius`/`context.textTheme`/`context.colorScheme`; импорт только `ui_kit.dart`. Скилл — `dartway-ui-kit`.
- **Навигация:** DartWay Router — enum-роуты, enum-параметры, переходы через context-extensions (`context.goNamed`/`pushTo`/`replaceWith`, не `router.go()`), гварды централизованно. Скилл — `dartway-navigation`.
- **Specials:** уведомления — `dw.notify.*` (не `SnackBar`); профиль — `ref.watchUserProfile`/`readUserProfile` (не `watchModel<UserProfile>`); действия из UI — `DwUiAction.create`; выход — `signOut()`.

## Shared (`__SHARED_PKG__`)

Чистый Dart, общий для сервера и флаттера (single source of truth для кросс-слойного). ✅ Можно: чистый Dart, зависимость от client-пакета. ❌ Нельзя: Flutter, серверные API, `Session`, IO, БД. Сюда — то, что должно вести себя **одинаково** на бэке и фронте (валидация формата, общие enum'ы, расчёты из полей без IO). Публичный API — в `lib/__SHARED_PKG__.dart`, реализация — в `lib/src/`.

## Client (`__CLIENT_PKG__`)

Сгенерированный Serverpod protocol (модели + клиент). **Руками не править** — пересоздаётся из YAML сервера через `serverpod generate`. Зависимость для shared / flutter / server.
