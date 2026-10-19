#!/usr/bin/env bash
# Test package lifecycle in the existing VM; installer writes use disposable XDG paths.
set -euo pipefail
package=$(realpath "${1:?Usage: bash test-vm-package.sh path/to/index-os.pkg.tar.zst}")
bash "$(dirname -- "${BASH_SOURCE[0]}")/verify-package.sh" "$package"
snapshot() {
    local path
    for path in "$HOME/.config/kdeglobals" "$HOME/.config/kwinrc" \
        "$HOME/.config/kglobalshortcutsrc" "$HOME/.config/index/features.json" \
        "$HOME/.config/index/setup-selection.json" \
        "$HOME/.local/share/index/intro/user/settings.json" \
        "$HOME/.local/share/index/intro/login/settings.json" /etc/greetd/config.toml; do
        if [ -f "$path" ]; then sha256sum "$path"; else printf 'absent: %s\n' "$path"; fi
    done
    readlink /etc/systemd/system/display-manager.service
}
before=$(snapshot)
sudo pacman -U --noconfirm "$package"
test "$(snapshot)" = "$before"
pacman -Qkk index-os
test -x /usr/share/index-os/tools/index-askpass.sh
index-setup --list >/dev/null
index-setup --components fastfetch --dry-run
index-intro --gui --status
echo 'PASS: native installation, launchers and existing configuration preservation'

fixture=$(mktemp -d /dev/shm/index-package-test.XXXXXX)
trap 'rm -rf "${fixture:?}"' EXIT
XDG_CONFIG_HOME="$fixture/config" XDG_DATA_HOME="$fixture/data" \
    index-setup --components fastfetch --no-packages --yes
fastfetch --config "$fixture/config/fastfetch/config.jsonc" --pipe >/dev/null
test "$(snapshot)" = "$before"
echo 'PASS: packaged component setup and Fastfetch render in isolated user directories'

sudo pacman -R --noconfirm index-os
test ! -e /usr/bin/index-setup
test ! -e /usr/share/index-os
test "$(snapshot)" = "$before"
sudo pacman -U --noconfirm "$package"
test "$(snapshot)" = "$before"
pacman -Qkk index-os
echo 'PASS: package removal/reinstall and desktop/login settings preserved'
