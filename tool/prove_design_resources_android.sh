#!/usr/bin/env bash
# Reproduce #664's symlink proof. Requires Flutter, Python 3, unzip and an
# Android release toolchain (flutter doctor -v). Run flutter pub get here first.
set -euo pipefail
repository="$(cd "$(dirname "$0")/.." && pwd)"
probe_root="$(mktemp -d)"
trap 'rm -rf "$probe_root"' EXIT
flutter create --empty --platforms android "$probe_root/design_probe_flutter"
mkdir -p "$probe_root/.dartway" "$probe_root/dw_studio/ui_kit/resources"
printf '{}\n' > "$probe_root/.dartway/design.json"
python3 - "$probe_root" <<'PY'
import base64
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
resource = root / 'dw_studio/ui_kit/resources/brand.png'
resource.write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='))
app = root / 'design_probe_flutter'
pubspec = app / 'pubspec.yaml'
pubspec.write_text(pubspec.read_text().replace(
    '\nflutter:\n', '\nflutter:\n  assets:\n    - dw_studio/ui_kit/resources/\n'))
dictionary = app / 'lib/ui_kit/assets/app_icon.dart'
dictionary.parent.mkdir(parents=True)
dictionary.write_text("enum AppIcon {\n  brand('dw_studio/ui_kit/resources/brand.png');\n"
                      "  const AppIcon(this.path);\n  final String path;\n}\n")
PY
cd "$probe_root/design_probe_flutter"
dart --packages="$repository/.dart_tool/package_config.json" \
  "$repository/packages/dartway_cli/bin/dartway.dart" \
  check --fix --type designResourcesInvalid
test -L dw_studio
flutter build apk --release
unzip -p build/app/outputs/flutter-apk/app-release.apk \
  assets/flutter_assets/dw_studio/ui_kit/resources/brand.png > "$probe_root/bundled.png"
cmp "$probe_root/dw_studio/ui_kit/resources/brand.png" "$probe_root/bundled.png"
echo 'Android release contains the symlinked resource under its normal asset key.'
