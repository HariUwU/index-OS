#!/usr/bin/env bash
# Isolated configuration checks. No installed themes or login sessions changed.
set -euo pipefail
src="$HOME/index-OS"
fixture=$(mktemp -d /dev/shm/index-setup-test.XXXXXX)
trap 'rm -rf "${fixture:?}"' EXIT
export XDG_CONFIG_HOME="$fixture/config" XDG_DATA_HOME="$fixture/data"
mkdir -p "$XDG_CONFIG_HOME/index" "$XDG_DATA_HOME/plasma/shells/org.index.desktop/contents/lockscreen/assets"
lock="$XDG_DATA_HOME/plasma/shells/org.index.desktop/contents/lockscreen"
touch "$lock/LockScreen.qml"
printf '{"personal":"keep"}\n' > "$XDG_CONFIG_HOME/index/features.json"
python3 "$src/tools/configure-features.py" --features clipboard
python3 - <<'PY'
import json, os
from pathlib import Path
f = json.loads((Path(os.environ['XDG_CONFIG_HOME'])/'index/features.json').read_text())
assert f['clipboard'] and f['shortcuts'] and not f['quicksettings']
PY
python3 "$src/tools/configure-features.py" --features ''
python3 "$src/tools/configure-features.py" --restore
grep -qx '{"personal":"keep"}' "$XDG_CONFIG_HOME/index/features.json"
echo 'PASS: selected feature dependencies and original settings restored'
ffmpeg -hide_banner -loglevel error -f lavfi -i color=c=blue:s=160x90:d=1 -c:v libx264 -pix_fmt yuv420p "$fixture/custom intro.mp4"
python3 "$src/tools/index-intro.py" --check-video "$fixture/custom intro.mp4"
test ! -d "$XDG_DATA_HOME/index/intro"
python3 "$src/tools/index-intro.py" --scope user --video "$fixture/custom intro.mp4"
cmp "$fixture/custom intro.mp4" "$lock/assets/intro-user.mp4"
grep -q 'enabled: true' "$lock/IntroConfig.qml"
grep -q 'intro-user.mp4' "$lock/IntroConfig.qml"
cp "$XDG_DATA_HOME/index/intro/user/settings.json" "$fixture/before.json"
printf 'invalid video' > "$fixture/invalid.mp4"
if python3 "$src/tools/index-intro.py" --scope user --video "$fixture/invalid.mp4" 2>"$fixture/error"; then
    echo 'FAIL: accepted invalid media'; exit 1
fi
cmp "$fixture/before.json" "$XDG_DATA_HOME/index/intro/user/settings.json"
python3 "$src/tools/index-intro.py" --scope user --disable
grep -q 'enabled: false' "$lock/IntroConfig.qml"
python3 "$src/tools/index-intro.py" --scope user --enable
grep -q 'intro-user.mp4' "$lock/IntroConfig.qml"
python3 "$src/tools/index-intro.py" --scope user --default
grep -q 'assets/intro.mp4' "$lock/IntroConfig.qml"
echo 'PASS: custom video copy, validation, disable/enable and original-video reset'
for script in install.sh install-desktop.sh install-greeter.sh setup.sh tools/install-extras.sh cursor/index-needle/build.sh; do
    bash -n "$src/$script"
done
python3 -m compileall -q "$src/tools/setup.py" "$src/tools/index-intro.py" "$src/tools/configure-features.py" "$src/bridge/index-kwin-bridge" "$src/bridge/configure-shortcuts.py"
bash "$src/setup.sh" --components fastfetch --dry-run > "$fixture/fastfetch-plan"
grep -q 'Dependencies: fastfetch' "$fixture/fastfetch-plan"
! grep -q '+ Desktop:' "$fixture/fastfetch-plan"
bash "$src/setup.sh" --components login --dry-run > "$fixture/login-plan"
! grep -q '+ Desktop:' "$fixture/login-plan"
bash "$src/setup.sh" --components clipboard --dry-run > "$fixture/clipboard-plan"
grep -q '+ Desktop:' "$fixture/clipboard-plan"
grep -q '+ Windows shortcuts:' "$fixture/clipboard-plan"
if bash "$src/setup.sh" --components unknown --dry-run 2>"$fixture/error"; then exit 1; fi
echo 'PASS: setup previews, component dependencies, syntax and invalid selections'
