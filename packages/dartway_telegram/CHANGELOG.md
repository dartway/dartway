# Changelog

## 0.6.0

- Targets DartWay 0.23

## 0.5.0

- Targets DartWay 0.22.

## 0.4.0

- Targets DartWay 0.21 (`dartway_core_*` `^0.21.0`).

## 0.3.0

- This package now targets the rewritten DartWay framework: `dartway_flutter` is now `dartway_core_flutter` `^0.20.0`, and the two-word renames that came with it (`DwFlutter` → `DwFlutterToolbox`, `DwConfig` → `DwFlutterConfig`, `DwPlugin` → `DwFlutterPlugin`, `DwPlugins` → `DwPluginRegistry`). `DwTelegramWebApp` now `extends DwFlutterPlugin` (it `implements DwPlugin` before) — otherwise the previously published `0.2.0` (on `dartway_flutter` `^0.5.0`) is identical.
