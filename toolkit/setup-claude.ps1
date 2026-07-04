<#
DartWay Claude toolkit installer (PowerShell, Windows).

Тянет generic-скиллы и команды dartway-* из монорепо DartWay (папка toolkit/) и ставит их в .claude/
этого репозитория, подставляя проектные значения (имена пакетов, базовую ветку).
.claude/ КОММИТИТСЯ в проект (генерируемый артефакт, как Serverpod-клиент). Перезаписываются только
управляемые файлы: CLAUDE.md, skills/dartway-*, commands/{commit,dartway-audit}.md — собственные
скиллы/команды проекта не трогаются.

Использование:
  .\tools\claude\setup-claude.ps1 <base-branch>          # напр. develop

Переменные окружения:
  DARTWAY_REPO_URL      git-URL монорепо dartway (по умолчанию см. ниже)
  DARTWAY_BRANCH        ветка монорепо (по умолчанию stable — последнее проверенное состояние)
  DARTWAY_TOOLKIT_DIR   путь к локальной папке toolkit/ (минует clone/pull) — для разработки тулкита

Пример (локальная разработка тулкита):
  $env:DARTWAY_TOOLKIT_DIR='..\dartway\toolkit'; .\tools\claude\setup-claude.ps1 develop
#>
param([Parameter(Mandatory = $true)][string]$BaseBranch)

$ErrorActionPreference = 'Stop'

$DartwayRepoUrl = if ($env:DARTWAY_REPO_URL) { $env:DARTWAY_REPO_URL } else { 'https://github.com/dartway/dartway.git' }
$DartwayBranch = if ($env:DARTWAY_BRANCH) { $env:DARTWAY_BRANCH } else { 'stable' }

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root
$Cache = 'tools/dw_claude_setup/.toolkit'

# 1. Источник тулкита: локальный чекаут или clone/pull remote
if ($env:DARTWAY_TOOLKIT_DIR) {
  $Src = $env:DARTWAY_TOOLKIT_DIR
  Write-Host "Источник тулкита (локальный): $Src"
  if (-not (Test-Path "$Src/skills") -or -not (Test-Path "$Src/commands")) {
    throw "В '$Src' нет skills/ и commands/"
  }
}
else {
  if (Test-Path "$Cache/.git") {
    Write-Host "Обновляю монорепо dartway ($DartwayBranch) в $Cache ..."
    git -C $Cache fetch --depth 1 origin $DartwayBranch
    if ($LASTEXITCODE -ne 0) { throw "git fetch не удался (ветка '$DartwayBranch')" }
    git -C $Cache checkout -B $DartwayBranch FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { throw "git checkout не удался" }
  }
  else {
    Write-Host "Клонирую монорепо $DartwayRepoUrl ($DartwayBranch) -> $Cache ..."
    if (Test-Path $Cache) { Remove-Item -Recurse -Force $Cache }
    git clone --depth 1 --branch $DartwayBranch $DartwayRepoUrl $Cache
    if ($LASTEXITCODE -ne 0) { throw "git clone не удался (ветка '$DartwayBranch' в $DartwayRepoUrl)" }
  }
  $Src = "$Cache/toolkit"
}

# 2. Авто-детект Dart-пакетов по роли (суффикс имени каталога)
function Find-Pkg([string]$Suffix, [bool]$Required) {
  $hits = @(Get-ChildItem -Directory -Path $Root -Filter "*_$Suffix" -ErrorAction SilentlyContinue)
  if ($hits.Count -eq 1) { return $hits[0].Name }
  elseif ($hits.Count -eq 0) {
    if ($Required) { throw "Не найден пакет *_$Suffix в корне репо" }
    return ''
  }
  else { throw "Неоднозначно — несколько пакетов *_$Suffix" }
}

$ServerPkg = Find-Pkg 'server' $true
$FlutterPkg = Find-Pkg 'flutter' $true
$ClientPkg = Find-Pkg 'client' $true
$SharedPkg = Find-Pkg 'shared' $false

Write-Host "Пакеты: server=$ServerPkg flutter=$FlutterPkg client=$ClientPkg shared=$SharedPkg"
Write-Host "Базовая ветка: $BaseBranch"

# 3. Установка с подстановкой токенов.
# Перезаписываем ТОЛЬКО управляемые файлы — собственные скиллы/команды проекта не трогаем.
Get-ChildItem -Directory -Path '.claude/skills' -Filter 'dartway-*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Remove-Item -Force '.claude/commands/commit.md', '.claude/commands/dartway-audit.md', '.claude/CLAUDE.md' -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path '.claude/skills', '.claude/commands' | Out-Null
Copy-Item -Recurse -Force "$Src/skills/*" '.claude/skills/'
Copy-Item -Recurse -Force "$Src/commands/*" '.claude/commands/'
Copy-Item "$Src/CLAUDE.md" '.claude/CLAUDE.md'

$map = [ordered]@{
  '__SERVER_PKG__'  = $ServerPkg
  '__FLUTTER_PKG__' = $FlutterPkg
  '__CLIENT_PKG__'  = $ClientPkg
  '__SHARED_PKG__'  = $SharedPkg
  '__BASE_BRANCH__' = $BaseBranch
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$managed = @(Get-ChildItem -Recurse -File -Path '.claude/skills/dartway-*' -Filter '*.md' -ErrorAction SilentlyContinue) +
  @(Get-Item '.claude/commands/commit.md', '.claude/commands/dartway-audit.md', '.claude/CLAUDE.md' -ErrorAction SilentlyContinue)
$managed | ForEach-Object {
  $content = Get-Content -Raw -LiteralPath $_.FullName
  foreach ($k in $map.Keys) { $content = $content.Replace($k, $map[$k]) }
  $content = $content -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
}

Write-Host "Готово: .claude/CLAUDE.md, .claude/skills и .claude/commands установлены с подстановками."
