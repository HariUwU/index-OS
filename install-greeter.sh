#!/usr/bin/env bash
# ============================================================
#  WILL OF THE CITY :: THE INDEX  —  login screen (greetd + Quickshell)
#
#  Replaces the KDE login screen (plasmalogin / sddm) with the INDEX
#  greeter: greetd runs  cage -s -- quickshell -p greeter.qml , and
#  a successful login starts the normal Plasma (KWin + INDEX) session.
#
#  Usage:  bash install-greeter.sh            install + switch to it
#          bash install-greeter.sh --restore  go back to the old login screen
#
#  This changes the machine's login screen, so it is separate from
#  install.sh and asks for sudo. The old display manager is only
#  disabled, never removed.
# ============================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=/usr/share/index-greeter
STATE=/var/lib/index-greeter
LOGIN_USER="${SUDO_USER:-$(id -un)}"
DO_PACKAGES=1
DO_RESTORE=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --restore) DO_RESTORE=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Run as your normal user (sudo is used where needed)."
[ -f "$SRC/greeter/greeter.qml" ] || die "greeter/greeter.qml not found next to this script."

# the display manager systemd starts at boot, e.g. plasmalogin.service / sddm.service
current_dm() {
    local alias=/etc/systemd/system/display-manager.service
    # readlink -f also succeeds for a nonexistent final path component.
    # Bare Arch has no alias yet; that is not a service to disable.
    [ -e "$alias" ] || return 0
    readlink -f "$alias" 2>/dev/null | xargs -r basename
}

# kscreenlocker "lock on start" would ask for the password twice after a greeter login
lock_on_start() {
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnStart "$1" 2>/dev/null || true
}

if [ "$DO_RESTORE" = 1 ]; then
    step "Restoring the previous login screen"
    old="$(cat "$STATE/previous-dm" 2>/dev/null || true)"
    [ -n "$old" ] || die "No saved login screen in $STATE/previous-dm"
    sudo systemctl disable greetd.service
    if [ "$old" != none ]; then
        sudo systemctl enable "$old"
        info "re-enabled $old (greetd is disabled, files are kept)"
    else
        info "no previous login manager; graphical login disabled (files are kept)"
    fi
    lock_on_start true
    if [ -f "$STATE/faillock.conf.orig" ]; then
        sudo cp "$STATE/faillock.conf.orig" /etc/security/faillock.conf
        info "restored /etc/security/faillock.conf"
    fi
    info "Reboot to see it."
    exit 0
fi

step "Installing greetd and cage"
if [ "$DO_PACKAGES" = 1 ]; then sudo pacman -S --needed --noconfirm greetd cage; fi

step "Provisioning persistent intro state"
sudo install -d -m 700 -o greeter -g "$(id -gn greeter)" /var/lib/index-greeter-intro

step "Installing the INDEX greeter to $DEST"
sudo rm -rf "${DEST:?}"
sudo mkdir -p "$DEST"
sudo cp -r "$SRC/greeter/." "$DEST/"
python3 "$SRC/tools/install-assets.py" --scope login
echo "$LOGIN_USER" | sudo tee "$DEST/user" >/dev/null
sudo chmod -R a+rX "$DEST"
sudo chmod 755 "$DEST/run-greeter"
info "default user: $LOGIN_USER"

step "Configuring greetd"
old="$(current_dm)"
sudo mkdir -p "$STATE"
if [ "$old" != "greetd.service" ]; then
    echo "${old:-none}" | sudo tee "$STATE/previous-dm" >/dev/null
    info "previous login screen: ${old:-none} (saved for --restore)"
fi
[ -f /etc/greetd/config.toml ] && [ ! -f "$STATE/config.toml.orig" ] &&
    sudo cp /etc/greetd/config.toml "$STATE/config.toml.orig"
sudo tee /etc/greetd/config.toml >/dev/null <<EOF
# THE INDEX login screen (written by index-OS install-greeter.sh)
[terminal]
vt = 1

[default_session]
command = "$DEST/run-greeter"
user = "greeter"
EOF

step "Making room for the WILL OF THE CITY protocol"
# The INDEX protocol starts at 3 wrong passwords (then asks the FIXER password).
# Linux's faillock also locks the account at 3 by default, which would refuse
# even a correct FIXER password. Lock only after 10 instead (still anti-guessing).
FL=/etc/security/faillock.conf
if [ -f "$FL" ]; then
    [ -f "$STATE/faillock.conf.orig" ] || sudo cp "$FL" "$STATE/faillock.conf.orig"
    if grep -qE '^[[:space:]]*deny[[:space:]]*=' "$FL"; then
        sudo sed -i -E 's/^[[:space:]]*deny[[:space:]]*=.*/deny = 10/' "$FL"
    else
        echo 'deny = 10' | sudo tee -a "$FL" >/dev/null
    fi
    info "faillock: account locks after 10 wrong passwords (was 3)"
fi

step "Switching the login screen to greetd"
[ -n "$old" ] && [ "$old" != "greetd.service" ] && sudo systemctl disable "$old"
sudo systemctl enable greetd.service
lock_on_start false
info "kscreenlocker LockOnStart=false (the greeter already asks for the password)"
python3 "$SRC/tools/index-intro.py" --scope login --apply

step "Done"
cat <<MSG

    The INDEX login screen is installed. Reboot to see it.
    If it ever fails, switch to a text console with Ctrl+Alt+F2, log in, and run:
        bash $SRC/install-greeter.sh --restore
MSG
