#!/usr/bin/env bash
# ============================================================
#  WILL OF THE CITY :: THE INDEX  —  installer (KWin + Quickshell)
#
#  Usage:  bash install.sh [--no-packages] [--features=CSV] [--restore]
#    (none)         install packages, copy files, apply settings
#    --no-packages  skip the pacman/AUR step
#    --restore      undo everything using the latest backup
#    --features=CSV optional desktop features (empty selects desktop only)
#
#  Run as your normal user. sudo is used only for pacman.
#  Safe to run twice.
# ============================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
IDX="$DATA/index"
BACKUPS="$IDX/backups"
UNIT_DIR="$CFG/systemd/user"
RC_FILES=(kdeglobals kwinrc kscreenlockerrc ksplashrc plasmarc plasmashellrc konsolerc kglobalshortcutsrc)
FEATURES=terminals,fastfetch,shortcuts,quicksettings,clipboard,prescript

DO_PACKAGES=1
DO_RESTORE=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --restore)     DO_RESTORE=1 ;;
        --features=*)  FEATURES="${arg#*=}" ;;
        -h|--help)     sed -n 2,11p "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done
has_feature() { case ",$FEATURES," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
IFS=, read -r -a feature_names <<< "$FEATURES"
for feature in "${feature_names[@]}"; do
    case "$feature" in terminals|fastfetch|shortcuts|quicksettings|clipboard|prescript|'') ;;
        *) echo "Unknown feature: $feature" >&2; exit 2 ;; esac
done
if has_feature clipboard && ! has_feature shortcuts; then FEATURES="${FEATURES:+$FEATURES,}shortcuts"; fi
PACKAGES=(quickshell python-dbus python-gobject qt6-multimedia qt6-5compat
          playerctl wireplumber networkmanager bluez-utils ttf-dejavu fontconfig ffmpeg kdialog)
has_feature clipboard && PACKAGES+=(wl-clipboard cliphist)
has_feature shortcuts && PACKAGES+=(spectacle plasma-systemmonitor)
has_feature quicksettings && PACKAGES+=(brightnessctl)
has_feature fastfetch && PACKAGES+=(fastfetch)
has_feature terminals && PACKAGES+=(konsole alacritty)

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root (sudo is used only for pacman)."

# Remove a directory we own, then make its parent again. The :? guards stop
# the script if a variable is ever empty.
fresh_dir() { rm -rf "${1:?}"; mkdir -p "$(dirname "${1:?}")"; }

# ------------------------------------------------------------
#  Restore
# ------------------------------------------------------------
restore() {
    step "Finding latest backup"
    local latest="" backup_name="" terminals_managed=0 fastfetch_managed=0
    [ -d "$BACKUPS" ] && backup_name="$(find "$BACKUPS" -regextype posix-extended -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9]+(-[0-9]+)?' -printf '%f\n' | LC_ALL=C sort -V | tail -n 1)"
    [ -n "$backup_name" ] || die "No backup found in $BACKUPS"
    latest="$BACKUPS/$backup_name"
    info "using $latest"

    # Completed snapshots keep ownership even after the helper clears installed
    # markers, so a repeated desktop restore cannot fall back to older settings.
    [ ! -f "$IDX/extras-backups/terminals/ready" ] || terminals_managed=1
    [ ! -f "$IDX/extras-backups/fastfetch/ready" ] || fastfetch_managed=1
    bash "$SRC/tools/install-extras.sh" --restore
    python3 "$SRC/tools/configure-features.py" --restore

    step "Restoring systemd user units"
    # Only unmask if WE masked it (the backup records the old state).
    if grep -qx 'plasma-plasmashell.service=masked' "$latest/units.txt" 2>/dev/null; then
        info "plasma-plasmashell was already masked before; leaving it masked"
    else
        systemctl --user unmask plasma-plasmashell.service 2>/dev/null || true
        info "plasma-plasmashell unmasked"
    fi
    systemctl --user disable index-shell.service 2>/dev/null || true
    systemctl --user stop index-shell.service 2>/dev/null || true
    rm -f "${UNIT_DIR:?}/index-shell.service"
    systemctl --user disable index-clipboard.service 2>/dev/null || true
    systemctl --user stop index-clipboard.service 2>/dev/null || true
    rm -f "${UNIT_DIR:?}/index-clipboard.service"
    systemctl --user daemon-reload 2>/dev/null || true

    step "Restoring config files"
    local f
    for f in "${RC_FILES[@]}"; do
        if [ "$f" = konsolerc ] && [ "$terminals_managed" = 1 ]; then continue; fi
        if [ -f "$latest/$f" ]; then
            cp -f "$latest/$f" "$CFG/$f"; info "restored $f"
        elif grep -qx "$f" "$latest/absent.txt" 2>/dev/null; then
            rm -f "${CFG:?}/${f:?}"; info "removed $f (did not exist before)"
        fi
    done
    # Old installations without extras snapshots still use their legacy backups.
    if [ "$fastfetch_managed" = 0 ]; then
        for f in config.jsonc index.txt; do
            if [ -f "$IDX/fastfetch-before-index/$f" ]; then
                mkdir -p "$CFG/fastfetch"
                cp -p "$IDX/fastfetch-before-index/$f" "$CFG/fastfetch/$f"
            elif grep -qx "$f" "$IDX/fastfetch-before-index/absent.txt" 2>/dev/null; then
                rm -f "${CFG:?}/fastfetch/$f"
            fi
        done
    fi
    if [ "$terminals_managed" = 0 ]; then
        if [ -f "$latest/alacritty.toml" ]; then
            mkdir -p "$CFG/alacritty"
            cp -f "$latest/alacritty.toml" "$CFG/alacritty/alacritty.toml"; info "restored alacritty/alacritty.toml"
        elif grep -qx 'alacritty/alacritty.toml' "$latest/absent.txt" 2>/dev/null; then
            rm -f "${CFG:?}/alacritty/alacritty.toml"; info "removed alacritty/alacritty.toml (did not exist before)"
        fi
        # Legacy backups never recorded ownership of alacritty.user.toml.
        # Keep it: only the extras helper can prove it created that file.
    fi
    rm -f "${IDX:?}/installed"
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

    step "Done"
    info "Installed theme files were left in place (they are harmless)."
    info "Log out and back in to get the Plasma shell back."
}

if [ "$DO_RESTORE" = 1 ]; then restore; exit 0; fi

# ------------------------------------------------------------
#  1. Packages
# ------------------------------------------------------------
step "Checking Plasma prerequisites"
for bin in kwin_wayland kwriteconfig6 kreadconfig6 qdbus6; do
    command -v "$bin" >/dev/null || die "'$bin' not found. Install KDE Plasma 6 first (pacman -S plasma-desktop)."
done
info "KWin / Plasma tools found"

if [ "$DO_PACKAGES" = 1 ]; then
    step "Installing packages"
    command -v pacman >/dev/null || die "pacman not found. This installer is for Arch / CachyOS. Use --no-packages."
    if sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
        info "packages installed"
    else
        # quickshell is in Arch 'extra'; if it is missing from your repos try an AUR helper.
        missing=()
        for p in "${PACKAGES[@]}"; do pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p"); done
        if [ "${#missing[@]}" -eq 0 ]; then
            info "all packages already present"
        else
            helper=""
            command -v paru >/dev/null && helper=paru
            if [ -z "$helper" ] && command -v yay >/dev/null; then helper=yay; fi
            [ -n "$helper" ] || die "pacman could not install: ${missing[*]}
    Install an AUR helper (paru or yay) and run again, or install by hand:
      paru -S ${missing[*]}
    Then run: bash install.sh --no-packages"
            info "using $helper for: ${missing[*]}"
            "$helper" -S --needed --noconfirm "${missing[@]}"
        fi
    fi
else
    step "Skipping packages (--no-packages)"
fi
command -v quickshell >/dev/null || die "quickshell is not installed. Install it, then run: bash install.sh --no-packages"

# ------------------------------------------------------------
#  2. Backup (only once per install; a second run keeps the first backup)
# ------------------------------------------------------------
step "Backing up current settings"
mkdir -p "$BACKUPS"
if [ -f "$IDX/installed" ]; then
    info "already installed before; keeping the existing backup"
else
    B="$BACKUPS/$(LC_ALL=C date +%Y%m%d-%H%M%S)"
    mkdir -p "$B"
    : > "$B/absent.txt"
    for f in "${RC_FILES[@]}"; do
        if [ -f "$CFG/$f" ]; then cp -p "$CFG/$f" "$B/$f"; info "saved $f"
        else echo "$f" >> "$B/absent.txt"; fi
    done
    if [ -f "$CFG/alacritty/alacritty.toml" ]; then
        cp -p "$CFG/alacritty/alacritty.toml" "$B/alacritty.toml"; info "saved alacritty/alacritty.toml"
    else echo "alacritty/alacritty.toml" >> "$B/absent.txt"; fi
    for u in plasma-plasmashell.service plasma-polkit-agent.service index-shell.service index-clipboard.service; do
        echo "$u=$(systemctl --user is-enabled "$u" 2>/dev/null || true)"
    done > "$B/units.txt"
    info "backup: $B"
fi

# ------------------------------------------------------------
#  3. Copy files
# ------------------------------------------------------------
step "Copying Quickshell config"
fresh_dir "$CFG/quickshell/index"
cp -r "$SRC/quickshell" "$CFG/quickshell/index"

step "Copying KWin bridge"
fresh_dir "$IDX/bridge"
cp -r "$SRC/bridge" "$IDX/bridge"
chmod +x "$IDX/bridge/index-kwin-bridge"

mkdir -p "$IDX/tools"
install -m 755 "$SRC/tools/index-intro.py" "$SRC/tools/index-askpass.sh" "$IDX/tools/"

EXTRAS=""
has_feature terminals && EXTRAS=terminals
has_feature fastfetch && EXTRAS="${EXTRAS:+$EXTRAS,}fastfetch"
if [ -n "$EXTRAS" ]; then bash "$SRC/tools/install-extras.sh" --components "$EXTRAS"; fi

step "Installing KWin decoration and colors"
fresh_dir "$DATA/aurorae/themes/index"
cp -r "$SRC/kde/aurorae/index" "$DATA/aurorae/themes/index"
mkdir -p "$DATA/color-schemes"
cp -f "$SRC/kde/color-schemes/IndexDark.colors" "$DATA/color-schemes/"

step "Installing look-and-feel (lock screen + splash)"
LNF="$DATA/plasma/look-and-feel/org.index.desktop"
fresh_dir "$LNF"
cp -r "$SRC/kde/look-and-feel/org.index.desktop" "$LNF"

step "Installing INDEX shell package (needed for the lock screen)"
# Plasma 6.6's screen locker takes its lock screen from the SHELL package,
# not from look-and-feel. So the shell package carries a copy of the
# lockscreen, plus its assets (fonts, logo, sounds). Layouts are not used:
# plasmashell is disabled, the shell package only exists for the locker.
SHELL_DIR="$DATA/plasma/shells/org.index.desktop"
fresh_dir "$SHELL_DIR"
cp -r "$SRC/kde/shells/org.index.desktop" "$SHELL_DIR"
mkdir -p "$SHELL_DIR/contents"
cp -r "$SRC/kde/look-and-feel/org.index.desktop/contents/lockscreen" "$SHELL_DIR/contents/lockscreen"

step "Installing canonical font and optional assets"
python3 "$SRC/tools/install-assets.py" --scope user
fc-cache -f >/dev/null 2>&1 || info "fc-cache failed (ignored)"

# ------------------------------------------------------------
#  4. Apply settings
# ------------------------------------------------------------
step "Applying settings"
kw() { kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"; }
kw kdeglobals General ColorScheme IndexDark
if command -v plasma-apply-colorscheme >/dev/null; then
    QT_QPA_PLATFORM=offscreen plasma-apply-colorscheme IndexDark >/dev/null 2>&1 || true
fi
# Use the repaired INDEX pixel font throughout KDE as well as the shell.
FONT="Perfect DOS VGA 437 Universal,12,-1,5,50,0,0,0,0,0"
kw kdeglobals General font "$FONT"
kw kdeglobals General menuFont "$FONT"
kw kdeglobals General toolBarFont "$FONT"
kw kdeglobals General fixed "$FONT"
kw kdeglobals General smallestReadableFont "Perfect DOS VGA 437 Universal,10,-1,5,50,0,0,0,0,0"
kw kdeglobals WM activeFont "$FONT"
# Already-open applications may need reopening to pick up their new fonts.
kw kwinrc org.kde.kdecoration2 library org.kde.kwin.aurorae
kw kwinrc org.kde.kdecoration2 theme __aurorae__svg__index
kw kwinrc Desktops Number 5
kw kwinrc Desktops Rows 1
# a running KWin (6.7) ignores Number=; create the missing desktops live
VDM="org.kde.KWin.VirtualDesktopManager"
for _ in 1 2 3 4; do
    n="$(qdbus6 org.kde.KWin /VirtualDesktopManager "$VDM.count" 2>/dev/null || echo 5)"
    [ "$n" -ge 5 ] && break
    qdbus6 org.kde.KWin /VirtualDesktopManager "$VDM.createDesktop" "$n" "" >/dev/null 2>&1 || break
done
# Windows key -> INDEX start menu.
# Plasma 6.7+: a bare Meta tap is a kglobalaccel shortcut owned by plasmashell's
# launcher. plasmashell is off, so free the key; kwin-bridge.js registers it as
# "THE INDEX: Start menu". (Takes effect at the next login.)
kw kglobalshortcutsrc plasmashell "activate application launcher" \
    "$(printf 'Alt+F1,Meta\tAlt+F1,Activate Application Launcher')"
# kglobalaccel runs inside KWin and keeps shortcuts in memory: free it live too
qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister \
    plasmashell "activate application launcher" >/dev/null 2>&1 || true
# older KWin versions read this instead
kw kwinrc ModifierOnlyShortcuts Meta "org.index.KWinBridge,/bridge,org.index.KWinBridge,ToggleStartMenu"

# ---- Windows-style shortcuts ---------------------------------------------
#  key             owner          how
#  -------------------------------------------------------------------------
#  Meta (tap)      INDEX script   start menu (above)
#  Meta+E          KDE default    [services][org.kde.dolphin.desktop] _launch -> Dolphin
#  Meta+I          KDE default    [services][systemsettings.desktop] _launch -> System Settings
#  Meta+D          KDE default    [kwin] "Show Desktop" (Peek at Desktop), left as is
#  Meta+Tab        KDE (KWin)     [kwin] "Overview": Meta+Tab added, Meta+W kept
#  Meta+V          INDEX script   clipboard history; freed from plasmashell (and the
#                                 old standalone klipper) "show-on-mouse-pos"
#  Meta+A          INDEX script   quick settings (no Plasma 6 default uses it)
#  Meta+Shift+S    INDEX script   region screenshot to the clipboard. Spectacle's own
#                                 region key is Meta+Shift+Print (left alone). If you
#                                 gave Spectacle Meta+Shift+S yourself, yours is kept.
#  Ctrl+Shift+Esc  INDEX script   System Monitor (KDE's Ctrl+Esc for it is kept)
#
#  E and I are not in kwin-bridge.js: KDE already does exactly that. If the
#  installed .desktop file has no such default, a [services] entry adds it
#  (still owned by KDE). Only keys INDEX takes over are freed; nothing else.
#  kglobalaccel lives inside KWin and keeps shortcuts in memory. Freed keys are
#  unregistered live too, but everything else here (Overview, the INDEX keys,
#  the [services] entries) takes effect after a RE-LOGIN.
GSC="$CFG/kglobalshortcutsrc"

# true if any shortcut except our own [kwin] "INDEX ..." ones has $1 as an
# ACTIVE key. A value is "active,default,description" (only "active" under
# [services][...]); several keys are tab-separated, written as \t by KConfig.
key_taken() {
    [ -f "$GSC" ] || return 1
    awk -v k="$1" '
        /^\[/ { grp = $0; next }
        /^[^#;].*=/ {
            name = substr($0, 1, index($0, "=") - 1)
            if (grp == "[kwin]" && name ~ /^INDEX /) next
            act = substr($0, index($0, "=") + 1); sub(/,.*/, "", act)
            n = split(act, ks, /\\t|\t/)
            for (i = 1; i <= n; i++) if (ks[i] == k) found = 1
        }
        END { exit found ? 0 : 1 }' "$GSC"
}

# free_key <component> <action> <key>: drop only <key> from that action's
# active keys (its other keys, default and description stay), then
# unregister the action live (only used for components that are not running).
free_key() {
    local cur act rest k had=0 new=()
    cur="$(kreadconfig6 --file kglobalshortcutsrc --group "$1" --key "$2" 2>/dev/null || true)"
    [ -n "$cur" ] || return 0
    act="${cur%%,*}"; rest="${cur#"$act"}"
    local IFS=$'\t'
    for k in $act; do
        if [ "$k" = "$3" ]; then had=1; else new+=("$k"); fi
    done
    [ "$had" = 1 ] || return 0
    act="${new[*]:-none}"
    kw kglobalshortcutsrc "$1" "$2" "$act$rest"
    qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister \
        "$1" "$2" >/dev/null 2>&1 || true
    info "freed $3 from $1 / $2"
}

# own_key <action> <label> <key>: pin a kwin-bridge.js shortcut to its key, so a
# stale "none" from an earlier, conflicting load does not stick.
own_key() {
    if key_taken "$3"; then
        info "$3 is already used by another shortcut; kept that one"
        info "  (THE INDEX: $2 can get a key in System Settings > Shortcuts > KWin)"
        return 0
    fi
    kw kglobalshortcutsrc kwin "$1" "$3,$3,THE INDEX: $2"
}

# ensure_launch <desktop file> <key>: make sure KDE's own launch shortcut exists
ensure_launch() {
    local desk="/usr/share/applications/$1" line
    [ -f "$desk" ] || return 0
    line="$(grep -m1 '^X-KDE-Shortcuts=' "$desk" 2>/dev/null || true)"
    case ",${line#X-KDE-Shortcuts=}," in *",$2,"*) return 0 ;; esac
    [ -z "$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$1" --key _launch 2>/dev/null || true)" ] || return 0
    key_taken "$2" && return 0
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "$1" --key _launch "$2"
    info "$2 opens $1"
}

if has_feature shortcuts; then
# 1) free first (live unregister makes kglobalaccel save its config) ...
free_key plasmashell show-on-mouse-pos Meta+V
free_key klipper     show-on-mouse-pos Meta+V
free_key plasmashell "switch to next activity" Meta+Tab
# 2) ... then write what INDEX / KDE should own
# Win+Tab: KWin overview (Meta+W still works)
kw kglobalshortcutsrc kwin Overview "$(printf 'Meta+Tab\tMeta+W,Meta+W,Toggle Overview')"
has_feature clipboard && own_key "INDEX Clipboard"      "Clipboard history"   Meta+V
has_feature quicksettings && own_key "INDEX Quick Settings" "Quick settings"      Meta+A
own_key "INDEX Screenshot"     "Screenshot (region)" Meta+Shift+S
own_key "INDEX Task Manager"   "Task manager"        Ctrl+Shift+Esc
ensure_launch org.kde.dolphin.desktop Meta+E
ensure_launch systemsettings.desktop  Meta+I
info "shortcuts set (log out and back in for all of them to apply)"
fi
if [ -f "$LNF/contents/splash/Splash.qml" ]; then
    kw ksplashrc KSplash Theme org.index.desktop
fi
# Lock screen: select the INDEX shell package so kscreenlocker uses our lockscreen.
kw plasmashellrc Shell ShellPackage org.index.desktop
# Like the original INDEX: sessions without its greeter start on its lock screen
# (also with auto-login).
# (not with the INDEX greeter from install-greeter.sh: it already asks once)
if [ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs -r basename)" = greetd.service ]; then
    kw kscreenlockerrc Daemon LockOnStart false
else
    kw kscreenlockerrc Daemon LockOnStart true
fi
# KDE defaults to locking after resume. Preserve the user's saved choice;
# reinstalling the desktop must not turn their disabled wake lock back on.

# ------------------------------------------------------------
#  5. Session
# ------------------------------------------------------------
step "Installing session units"
mkdir -p "$UNIT_DIR"
cp -f "$SRC/session/index-shell.service" "$UNIT_DIR/index-shell.service"
# clipboard history for Win+V (cliphist; klipper lived inside plasmashell)
cp -f "$SRC/session/index-clipboard.service" "$UNIT_DIR/index-clipboard.service"
systemctl --user daemon-reload
systemctl --user enable index-shell.service
if has_feature clipboard; then
    systemctl --user enable index-clipboard.service
else
    systemctl --user disable --now index-clipboard.service 2>/dev/null || true
fi
# Plasma 6 starts plasmashell as this unit. Mask it so Quickshell owns the screen.
# Do NOT mask plasma-polkit-agent.service (password prompts need it).
# Plasma's notification server lives inside plasmashell, so Quickshell
# provides notifications itself. krunner is only started on demand.
systemctl --user mask plasma-plasmashell.service

step "Reloading KWin"
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || info "KWin not running here (ignored)"

# Update the live shortcut registry too: KWin otherwise overwrites the file
# with its cached assignments. Preserve Alt+Tab while moving Meta+Tab.
python3 "$SRC/tools/configure-features.py" --features "$FEATURES"
if has_feature shortcuts; then
    python3 "$IDX/bridge/configure-shortcuts.py" || info "Log in to Plasma and rerun the installer to apply Win+Tab"
else
    python3 "$IDX/bridge/configure-shortcuts.py" --disable || true
fi

touch "$IDX/installed"
python3 "$SRC/tools/index-intro.py" --scope user --apply

step "Done"
cat <<MSG

    THE INDEX is installed.
    >>> LOG OUT AND BACK IN to start the new shell. <<<

    To undo everything:   bash $SRC/install.sh --restore
MSG
