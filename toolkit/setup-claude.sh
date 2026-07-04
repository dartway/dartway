#!/usr/bin/env bash
# DartWay Claude toolkit installer.
#
# Тянет generic-скиллы и команды dartway-* из монорепо DartWay (папка toolkit/) и ставит их в
# .claude/ этого репозитория, подставляя проектные значения (имена пакетов, базовую ветку).
# .claude/ КОММИТИТСЯ в проект (генерируемый артефакт, как Serverpod-клиент). Перезаписываются
# только управляемые файлы: CLAUDE.md, skills/dartway-*, commands/{commit,dartway-audit}.md —
# собственные скиллы/команды проекта не трогаются.
#
# Использование:
#   ./tools/dw_claude_setup/setup-claude.sh <base-branch>          # напр. develop
#
# Переменные окружения:
#   DARTWAY_REPO_URL      git-URL монорепо dartway (по умолчанию см. ниже)
#   DARTWAY_BRANCH        ветка монорепо (по умолчанию stable — последнее проверенное состояние)
#   DARTWAY_TOOLKIT_DIR   путь к локальной папке toolkit/ (минует clone/pull) — для разработки тулкита
#
# Пример (локальная разработка тулкита):
#   DARTWAY_TOOLKIT_DIR=../dartway/toolkit ./tools/dw_claude_setup/setup-claude.sh develop

set -euo pipefail

DARTWAY_REPO_URL="${DARTWAY_REPO_URL:-https://github.com/dartway/dartway.git}"
DARTWAY_BRANCH="${DARTWAY_BRANCH:-stable}"

BASE_BRANCH="${1:-}"
if [ -z "$BASE_BRANCH" ]; then
  echo "ОШИБКА: укажи базовую ветку. Пример: ./tools/dw_claude_setup/setup-claude.sh develop" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CACHE="tools/dw_claude_setup/.toolkit"

# 1. Источник тулкита: локальный чекаут или clone/pull remote
if [ -n "${DARTWAY_TOOLKIT_DIR:-}" ]; then
  SRC="$DARTWAY_TOOLKIT_DIR"
  echo "Источник тулкита (локальный): $SRC"
  if [ ! -d "$SRC/skills" ] || [ ! -d "$SRC/commands" ]; then
    echo "ОШИБКА: в '$SRC' нет skills/ и commands/" >&2
    exit 1
  fi
else
  if [ -d "$CACHE/.git" ]; then
    echo "Обновляю монорепо dartway ($DARTWAY_BRANCH) в $CACHE ..."
    git -C "$CACHE" fetch --depth 1 origin "$DARTWAY_BRANCH"
    git -C "$CACHE" checkout -B "$DARTWAY_BRANCH" FETCH_HEAD
  else
    echo "Клонирую монорепо $DARTWAY_REPO_URL ($DARTWAY_BRANCH) → $CACHE ..."
    rm -rf "$CACHE"
    git clone --depth 1 --branch "$DARTWAY_BRANCH" "$DARTWAY_REPO_URL" "$CACHE"
  fi
  SRC="$CACHE/toolkit"
fi

# 2. Авто-детект Dart-пакетов по роли (суффикс имени каталога)
detect_pkg() {
  local suffix="$1" required="$2" d found="" count=0
  for d in ./*_"$suffix"; do
    [ -d "$d" ] || continue
    found="$(basename "$d")"
    count=$((count + 1))
  done
  if [ "$count" -eq 1 ]; then
    printf '%s' "$found"
  elif [ "$count" -eq 0 ]; then
    if [ "$required" = "1" ]; then
      echo "ОШИБКА: не найден пакет *_$suffix в корне репо" >&2
      exit 1
    fi
    printf ''
  else
    echo "ОШИБКА: неоднозначно — несколько пакетов *_$suffix" >&2
    exit 1
  fi
}

SERVER_PKG="$(detect_pkg server 1)"
FLUTTER_PKG="$(detect_pkg flutter 1)"
CLIENT_PKG="$(detect_pkg client 1)"
SHARED_PKG="$(detect_pkg shared 0)"

echo "Пакеты: server=$SERVER_PKG flutter=$FLUTTER_PKG client=$CLIENT_PKG shared=${SHARED_PKG:-<нет>}"
echo "Базовая ветка: $BASE_BRANCH"

# 3. Установка с подстановкой токенов.
# Перезаписываем ТОЛЬКО управляемые файлы — собственные скиллы/команды проекта не трогаем.
rm -rf .claude/skills/dartway-* .claude/commands/commit.md .claude/commands/dartway-audit.md .claude/CLAUDE.md
mkdir -p .claude/skills .claude/commands
cp -r "$SRC/skills/." .claude/skills/
cp -r "$SRC/commands/." .claude/commands/
cp "$SRC/CLAUDE.md" .claude/CLAUDE.md

find .claude/skills/dartway-* .claude/commands/commit.md .claude/commands/dartway-audit.md .claude/CLAUDE.md -type f -name '*.md' -print0 | while IFS= read -r -d '' f; do
  sed -i \
    -e "s/__SERVER_PKG__/$SERVER_PKG/g" \
    -e "s/__FLUTTER_PKG__/$FLUTTER_PKG/g" \
    -e "s/__CLIENT_PKG__/$CLIENT_PKG/g" \
    -e "s/__SHARED_PKG__/$SHARED_PKG/g" \
    -e "s/__BASE_BRANCH__/$BASE_BRANCH/g" \
    "$f"
done

echo "Готово: .claude/CLAUDE.md, .claude/skills и .claude/commands установлены с подстановками."
