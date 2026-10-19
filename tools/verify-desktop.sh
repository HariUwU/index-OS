#!/usr/bin/env bash
# Read-only checks for the running INDEX desktop; UI checks are documented separately.
set -euo pipefail
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_tools() {
    local bin
    for bin in "$@"; do
        command -v "$bin" >/dev/null || fail "Missing tool: $bin"
    done
}
require_tools python3 quickshell kreadconfig6 kwriteconfig6 qdbus6 kwin_wayland \
    startplasma-wayland dolphin systemsettings pkexec wpctl pactl nmcli bluetoothctl

systemctl --user is-active --quiet plasma-polkit-agent.service || fail 'KDE polkit agent is not active'
wpctl status >/dev/null || fail 'PipeWire/WirePlumber is not reachable'
pactl info >/dev/null || fail 'PulseAudio-compatible audio server is not reachable'
echo 'PASS: desktop applications, polkit agent and audio servers (hardware playback not checked)'
features=$(python3 - "$cfg/index/features.json" <<'PY'
import json
from pathlib import Path
import sys

try:
    selected = json.loads(Path(sys.argv[1]).read_text())
except FileNotFoundError:
    selected = {}  # Features.qml defaults to all enabled for older installations.
except (OSError, ValueError) as error:
    sys.exit(f'FAIL: Cannot read INDEX feature settings: {error}')
if not isinstance(selected, dict):
    sys.exit('FAIL: INDEX feature settings must be a JSON object')
names = ('terminals', 'fastfetch', 'shortcuts', 'quicksettings', 'clipboard', 'prescript')
print(','.join(name for name in names if selected.get(name) is not False))
PY
)
has_feature() { case ",$features," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
printf 'Checking INDEX features: %s\n' "${features:-desktop only}"

systemctl --user is-active --quiet index-shell.service
echo 'PASS: desktop service'
if has_feature clipboard; then
    systemctl --user is-active --quiet index-clipboard.service
    require_tools wl-copy wl-paste cliphist
    echo 'PASS: clipboard service and tools'
else
    if systemctl --user is-active --quiet index-clipboard.service; then
        fail 'Clipboard is disabled but index-clipboard.service is active'
    fi
    echo 'PASS: disabled clipboard service is inactive'
fi
if has_feature shortcuts; then require_tools spectacle plasma-systemmonitor; fi
if has_feature quicksettings; then require_tools brightnessctl; fi
if has_feature terminals; then require_tools konsole alacritty; fi
if has_feature fastfetch; then require_tools fastfetch; fi
echo 'PASS: selected feature tools installed'

python3 - "$features" <<'PY'
import dbus
import sys

features = set(filter(None, sys.argv[1].split(',')))
b = dbus.SessionBus()
a = dbus.Interface(b.get_object('org.kde.kglobalaccel', '/kglobalaccel'), 'org.kde.KGlobalAccel')

def keys_for(name):
    return [int(key) for key in a.shortcut(['kwin', name, 'KWin', name]) if int(key)]

keys = keys_for('Walk Through Windows')
assert 0x09000001 in keys, 'Alt+Tab missing'
if 'shortcuts' in features:
    owners = a.getGlobalShortcutsByKey(0x11000001)
    assert len(owners) == 1 and owners[0][0] == 'Overview', ('Win+Tab owners', owners)
    for name in ('Walk Through Windows', 'Walk Through Windows (Reverse)'):
        assert 0x11000001 not in keys_for(name), 'Win+Tab still conflicts with ' + name
else:
    assert 0x11000001 not in keys_for('Overview'), 'Optional Win+Tab Overview binding still enabled'

# Query registration as well as bindings: a disabled action with no key is stale.
# KDE API: https://github.com/KDE/kglobalaccel/blob/master/src/org.kde.KGlobalAccel.xml
registered = {str(action[1]) for action in a.allActionsForComponent(['kwin', '', 'KWin', ''])}
for name, feature in [('INDEX Clipboard', 'clipboard'), ('INDEX Quick Settings', 'quicksettings'),
                      ('INDEX Screenshot', 'shortcuts'), ('INDEX Task Manager', 'shortcuts')]:
    enabled = 'shortcuts' in features and feature in features
    if enabled:
        assert name in registered and keys_for(name), name + ' is missing or has no key'
    else:
        assert name not in registered, name + ' is disabled but still registered'
        assert not keys_for(name), name + ' is disabled but still bound'
assert 'INDEX Task View' not in registered, 'Obsolete INDEX Task View is still registered'
print('PASS: Alt+Tab, selected shortcuts and absence of disabled INDEX actions')
PY
for key in font fixed menuFont toolBarFont smallestReadableFont; do
    kreadconfig6 --file kdeglobals --group General --key "$key" | grep -q '^Perfect DOS VGA 437 Universal,'
done
kreadconfig6 --file kdeglobals --group WM --key activeFont | grep -q '^Perfect DOS VGA 437 Universal,'
echo 'PASS: KDE uses INDEX fonts'
if has_feature fastfetch; then
    test -s "$cfg/fastfetch/index.txt"
    fastfetch --config "$cfg/fastfetch/config.jsonc" --pipe >/dev/null
    echo 'PASS: INDEX fastfetch config and logo render'
else
    echo 'SKIP: Fastfetch is not selected'
fi
