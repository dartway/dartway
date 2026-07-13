# DartWay — монорепо фреймворка

Это репозиторий **самого фреймворка** DartWay (fullstack Dart: Flutter + Serverpod), а не приложения на нём. Для приложений методология лежит в `toolkit/` и ставится в их `.claude/` установщиком — не путай два CLAUDE.md: этот — про разработку фреймворка.

## Карта монорепо

| Папка | Роль |
|---|---|
| `packages/dartway_serverpod_core/` | Ядро (4 пакета: server / client / flutter / shared) — generic CRUD, real-time, auth, фильтры |
| `packages/dartway_flutter` | Flutter-тулбокс: DwAppRunner, UI kit, нотификации |
| `packages/dartway_lints` | Enforcement конвенций (custom_lint-правила) |
| `packages/dartway_cli` | CLI: `create` / `setup-ai` / `check` (встроенный чекер конвенций) / `stats` |
| `example/` | Канонический проект — источник правды для доков, шаблона и учебного трека |
| `toolkit/` | Claude-обвязка для app-проектов (скиллы `dartway-*`, токены `__*__`, установщик) |
| `docs/` | Markdown-контент документации — целевой источник для сайта dartway.dev. **Внимание:** пайплайн docs/ → сайт ещё не настроен — сайт пока тянет контент из легаси-репо `dartway_guidelines` (см. `website/update_docs.dart`) |
| `website/` | Сайт dartway.dev (Docusaurus → GitHub Pages). **Публичный вложенный git-репо** (`novikov-it/dartway.dev`), gitignored — коммитить и пушить отдельно, изнутри `website/` |
| `project/` | Управление проектом: стратегия, roadmap, очередь задач — вход через `/next`. **Приватный вложенный git-репо** (`dartway/dartway_manager`), в публичный монорепо не коммитится (gitignored) — коммитить и пушить его отдельно, изнутри `project/` |
| `platform/` | **DartWay Studio** — закрытая платформа (живое превью + паспорта экранов; дальше фидбек/трекер/агенты). **Приватный вложенный git-репо** (`dartway/dartway_studio`), gitignored — коммитить и пушить отдельно, изнутри `platform/`. Открытая часть связки — `packages/dartway_studio_bridge` |
| `packages/dartway_studio_bridge` | Открытый мост приложение ↔ Studio: модели спеков экранов (в коде приложения) + runtime postMessage-протокол (host в приложении, client в Studio) |

## Закон синхронизации (Definition of Done)

Монорепо существует ради синхронной эволюции. Изменение **публичного API** любого пакета не завершено, пока в том же PR не обновлены:

1. `example/` — компилируется и использует новый API;
2. затронутые скиллы в `toolkit/skills/` (скилл, отставший от API, хуже отсутствующего — агент уверенно пишет неработающий код);
3. `docs/` — затронутые страницы;
4. `CHANGELOG.md` пакета.

Перед коммитом изменений фреймворка прогоняй скилл `framework-finish` — он ищет рассинхроны по диффу.

## Стандарты

- **Версионирование:** semver. Четвёрка `dartway_serverpod_core_*` — lockstep (одна версия на все четыре). Остальные пакеты — независимо.
- **Workspace-гигиена:** внутри монорепо зависимости между пакетами резолвятся через workspace (корневой `pubspec.yaml`), **не** через git-ссылки на `dartway.git`.
- **Язык:** всё публичное (доки, README пакетов, строки ошибок, комментарии в коде ядра) — английский. `project/`, `toolkit/` и внутренние обсуждения — русский.
- **Коммиты:** conventional commits — `feat:` / `fix:` / `chore:` (+ scope по желанию: `feat(session): ...`).
- **Ветки:** `master` — транк разработки (может быть «в разобранном виде»); `stable` — последнее проверенное состояние, **только fast-forward с master**, своя история запрещена. На `stable` смотрят: setup-скрипты/CLI (дефолтный канал) и git-зависимости внешних проектов. **Ритуал промоушена:** analyze/tests зелёные + example собирается и запускается + `framework-finish` без рассинхронов → `git push origin master:stable`. Гитфлоу (develop, release-ветки) не заводим.
- **Тулкит-инвариант:** в `toolkit/` нет проектных литералов — только токены `__*__`. Проверка: `grep -rniE 'tvolkova|tvaity|kerla' toolkit/` → пусто.
- **Архивы:** папки `zarchive/`/`zarchiv/` — легаси на выпил; ничего нового туда не добавлять, при рефакторинге — удалять, а не пополнять.
- **Секьюрити-принцип (цель):** generic CRUD должен быть secure-by-default — не сконфигурирован доступ ⇒ запрещено. Новый код не должен вводить «открыто всем» как умолчание.

## Ловушка: `serverpod generate` в ядре стирает ручной патч протокола

**Это для Claude — Евгений генерацию не запускает.** Прогнал `serverpod generate` в `packages/dartway_serverpod_core/dartway_serverpod_core_server` — обязан проверить и восстановить патч в сгенерированном `dartway_serverpod_core_client/lib/src/protocol/protocol.dart`.

**Что за патч.** В `Protocol.deserialize<T>`, сразу после `t ??= T;`, должен стоять блок:

```dart
if (data is Map<String, dynamic>) {
  final manualDeserialization =
      _iNN.DwApiResponse.manualDeserialization<T>(data);
  if (manualDeserialization != null) {
    return manualDeserialization;
  }
}
```

`_iNN` — **алиас импорта `dw_api_response.dart` в заново сгенерированном файле**, а не константа: номер меняется от генерации к генерации (сейчас `_i19`). Возьми его из шапки файла, не копируй вслепую.

**Почему без него всё разваливается.** `extraClasses` в Serverpod не понимает дженерики: для `DwApiResponse<T>` генератор пишет проверку по **сырому** типу — `if (t == _i19.DwApiResponse)`, то есть `DwApiResponse<dynamic>`. А на проводе приезжают `DwApiResponse<DwModelWrapper>`, `<List<DwModelWrapper>>`, `<int>`, `<bool>` — как `Type` они сырому не равны, ветка не срабатывает **никогда**, и любой CRUD-ответ падает на десериализации. Патч подставляет `DwApiResponse.manualDeserialization<K>`, которая разбирает конкретные инстанциации руками.

**Проверка после генерации:**

```bash
grep -n 'manualDeserialization' packages/dartway_serverpod_core/dartway_serverpod_core_client/lib/src/protocol/protocol.dart
```

Пусто → патч потерян, приложение сломано в рантайме (компиляция при этом проходит — в этом и коварство). Восстановить и убедиться, что example поднимается и грузит списки.

Разовое лечение мины (в очереди, не сделано): идемпотентный скрипт-патчер + регрессионный тест в `core_client`, который краснеет, если патч не на месте. Радикальное — убрать дженерики с провода, но это переделка CRUD-эндпоинтов, а Serverpod после v1 всё равно выпиливается.

## Рабочий процесс

Вход в рабочую сессию — команда **`/next`**: брифинг по `project/` (где мы, что сделано, напоминания о личных действиях Евгения), выбор задачи, работа, обновление `project/NEXT.md` в конце. Ключевые решения фиксируются строкой в `project/DECISIONS.md`.
