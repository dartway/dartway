---
name: dartway-models
description: >-
  Серверные YAML-модели Serverpod в DartWay: файлы .spy.yaml в lib/src/models/<domain>/,
  enum'ы в enums/. Base vs Event-модели (текущее состояние vs изменения над базой — для денег/
  транзакций), типы полей и дисциплина nullable (nullable только если значение реально отсутствует
  в домене), связи 1-1/1-N/N-N через relation(name=...) (двунаправленные — одинаковый name с обеих
  сторон), onDelete=Cascade, indexes/unique, default=, enum-модели (serialized: byName). Workflow:
  правка YAML → serverpod generate → create-migration → DwCrudConfig + регистрация в crudConfigurations
  → миграции на старте. Использовать при создании/изменении моделей, полей, связей, enum'ов и схемы БД.
---

# DartWay — модели (Serverpod, сервер)

**Domain-first:** любая фича начинается с модели(ей) (закон №2). Модель отражает доменную реальность, а не сиюминутные нужды UI. Схема — единый источник; Flutter-модели генерируются из неё, руками не дублируются. См. также `__SERVER_PKG__/CLAUDE.md`, `dartway-crud-config`, `docs/1_general/SERVER_ARCHITECTURE.md`.

## Где живут модели

- Файлы — **`lib/src/models/<domain>/<model>.spy.yaml`** (расширение `.spy.yaml`, не просто `.yaml`).
- Enum'ы домена — в подпапке `enums/` рядом (`.spy.yaml` с `enum:`).
- Имя класса — минимум 2 слова (`UserProfile`, `AnalyticsEvent`), `table` — snake_case.

## Структура модели

```yaml
class: UserProfile
table: user_profile
fields:
  createdAt: DateTime
  userIdentifier: String
  telegramId: String?              # nullable — значение реально может отсутствовать
  isAdmin: bool, default=false     # default для не-nullable с разумным значением
  email: String?
  quizFinancialGoal: FinancialGoal?    # ссылка на enum-модель
  courses: List<UserCourse>?, relation(name=user_profile_courses)   # 1-N
  completedLessonsIds: List<int>?      # примитивный список — без relation
indexes:
  user_profile_email_index:
    fields: email
    unique: true
```

## Дисциплина nullable (важно)

**Зачем:** nullable-поля заражают весь стек проверками `?`/`!`. Делай поле nullable, **только если значение реально может отсутствовать в домене**.

```yaml
# ❌ nullable «ради удобства редактирования формы»
title: String?      # хотя у сущности всегда есть title
# ✅ для form-state на флаттере — отдельная form-модель; в доменной модели поле обязательное
title: String
# ✅ default вместо nullable, когда есть осмысленное значение по умолчанию
isDeleted: bool, default=false
```

## Base vs Event-модели

**Зачем:** для транзакционных/денежных потоков опасно менять поле базовой модели напрямую (гонки, нет аудита, правила размазаны). Event-модель фиксирует **изменение над базой**.

- **Base** — текущее состояние сущности (`UserProfile`).
- **Event** — событие/изменение (`AnalyticsEvent`, `BalanceEvent`). Не меняй `UserProfile.balance` напрямую — создавай `BalanceEvent`: безопасность от гонок, аудит, единое место бизнес-правил (3 уровня усложнения логики — Event-модели идут первыми, до конфигурации CRUD и тем более custom-эндпоинтов).

## Связи (всегда явные)

**Зачем:** связи описаны в схеме, а не выводятся из id руками. Двунаправленная связь — **одинаковый `relation(name=...)` с обеих сторон**.

```yaml
# UserProfile (одна сторона 1-N)
courses: List<UserCourse>?, relation(name=user_profile_courses)

# UserCourse (другая сторона — тот же name)
userProfile: UserProfile?, relation(name=user_profile_courses, onDelete=Cascade)
course: LearningCourse?, relation(onDelete=Cascade)   # односторонняя ссылка — name не обязателен
```

- 1-1 / 1-N / N-N — все явные. `onDelete=Cascade` — каскадное удаление зависимых.
- Поля связей с пользователем — со словом **Profile** в имени (`userProfileId`, `authorProfileId`) — закон нейминга №5.

## Enum-модели

```yaml
enum: AnalyticsAccessType
serialized: byName        # byName — устойчиво к перестановке значений (предпочтительно)
values:
  - free
  - paid
  - trial
```

## Workflow изменения модели

1. Правишь/добавляешь `.spy.yaml` в `lib/src/models/<domain>/`.
2. `dart run serverpod generate` — обновляет generated + `__CLIENT_PKG__`.
3. `dart run serverpod create-migration` (`--force` только на раннем MVP, если старые миграции можно перезаписать).
4. Настраиваешь `DwCrudConfig` в `/crud` (см. `dartway-crud-config`) и **регистрируешь в `crudConfigurations`** при `DwCore.init` — иначе API вернёт `notConfigured`.
5. Логика: `/domain` (чистая) или `/app` (session-aware).
6. Миграции применяются на старте (`--apply-migrations`) или `dart run serverpod migrate`.
7. Тесты (юнит на конфиг и Event-модели).

## Чек-лист модели

- [ ] Файл `.spy.yaml` в `lib/src/models/<domain>/`; enum'ы — в `enums/`.
- [ ] Имя класса ≥2 слов; `table` snake_case.
- [ ] Nullable — только если значение реально отсутствует в домене (не «ради формы»); где уместно — `default=`.
- [ ] Связи явные; двунаправленные — одинаковый `relation(name=...)` с обеих сторон; поля связей с пользователем со словом `Profile`.
- [ ] Транзакционная/денежная логика — через Event-модель, а не прямой апдейт поля.
- [ ] После правки: `serverpod generate` → `create-migration`; новая модель добавлена в `crudConfigurations` с `DwCrudConfig`.
- [ ] Enum — `serialized: byName`.
