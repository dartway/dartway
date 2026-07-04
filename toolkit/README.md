# DartWay Claude Toolkit

Обвязка Claude Code для приложений на DartWay: переиспользуемые скиллы и команды `dartway-*`. **Единый источник правды** — папка `toolkit/` монорепо `dartway`: скиллы версионируются и эволюционируют вместе с кодом фреймворка (изменение публичного API пакета обновляет затронутые скиллы в том же PR — см. корневой `CLAUDE.md` монорепо).

В клиентские репо обвязка ставится скриптом и **коммитится** (`.claude/` — генерируемый-но-коммитимый артефакт, как Serverpod-клиент): клонировал проект — скиллы уже на месте, история фиксирует, с какими скиллами писался код, обновление — осознанное действие с видимым диффом. Установщик перезаписывает **только управляемые файлы** (`CLAUDE.md`, скиллы `dartway-*`, команды `commit`/`dartway-audit`) — собственные скиллы и команды проекта живут рядом под своими именами и не трогаются. Хочешь кастомизировать dartway-скилл — скопируй под другим именем.

## Структура

```
CLAUDE.md                     # generic-методология (always-in-context «мозг»): законы, нейминг,
                              #   слои server/flutter/shared/client, каталог скиллов; ставится как .claude/CLAUDE.md
skills/dartway-*/SKILL.md     # методология DartWay (clean-code, models, crud-config, data-layer,
                              #   navigation, ui-kit, feature-scaffold, finish)
commands/{commit,dartway-audit}.md
setup-claude.sh / .ps1        # установщик (копия для новых клиентских репо)
```

`CLAUDE.md` ставится в `.claude/CLAUDE.md` (gitignored), который Claude Code автоматически держит в контексте — поэтому проектных `CLAUDE.md` в клиентском репо не нужно: методология едет из тулкита, а проектное знание живёт в `docs/`.

Скиллы — **generic**: проектные значения вынесены в плейсхолдер-токены, которые установщик подставляет при инсталляции:

| Токен | Значение | Откуда |
|---|---|---|
| `__SERVER_PKG__` / `__CLIENT_PKG__` / `__FLUTTER_PKG__` / `__SHARED_PKG__` | имена Dart-пакетов | авто-детект по `*_server`/`*_client`/`*_flutter`/`*_shared` |
| `__BASE_BRANCH__` | базовая ветка | параметр запуска установщика |

Пути docs (`docs/2_features`, `docs/1_general`, `docs/audits`) — конвенция DartWay, зашиты как есть. Тикет в `/commit` передаётся аргументом, формат проверяет CI проекта.

## Подключение к клиентскому репо

В клиентский репо кладётся `tools/dw_claude_setup/setup-claude.{sh,ps1}` (копия отсюда) + строка `tools/dw_claude_setup/.toolkit/` в `.gitignore` (кэш клона; сам `.claude/` — коммитится). Затем:

```bash
./tools/dw_claude_setup/setup-claude.sh <base-branch>      # напр. develop
```

Установщик клонит/пуллит монорепо `dartway` (по умолчанию ветка **`stable`** — последнее проверенное состояние; канал можно сменить через `DARTWAY_BRANCH=master`), берёт из него `toolkit/`, детектит пакеты, подставляет токены и наполняет `.claude/`.

> Скрипты — временное решение: их заменит `dartway_cli` (`dartway create` / `dartway setup-ai`), который после выхода пакетов на pub.dev будет брать скиллы из `.pub-cache` точно под версию пакетов проекта.

## Разработка тулкита

Правь скиллы **здесь** (в `toolkit/` монорепо) и пушь. Быстрый цикл правка→тест — ставить в реальный проект из локального чекаута:

```bash
DARTWAY_TOOLKIT_DIR=../dartway/toolkit ./tools/dw_claude_setup/setup-claude.sh develop
```

Правка → re-run setup в проекте → тест → `git push`. Обратной синхронизации нет: источник правды всегда здесь.

Инвариант: в `CLAUDE.md`, `skills/` и `commands/` **не должно быть проектных литералов** — только токены `__*__`. Проверка:

```bash
grep -rniE 'tvolkova|tvaity|kerla|RAZRABOTKA|BAGI|DEVOPS' CLAUDE.md skills commands   # должно быть пусто
```
