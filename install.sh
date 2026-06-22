#!/usr/bin/env bash
# ============================================================
#  WILL OF THE CITY :: THE INDEX
#  Hyprland rice installer  (Arch Linux)
# ============================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYAN=$'\033[38;2;93;173;226m'; RED=$'\033[38;2;255;107;107m'; DIM=$'\033[38;2;58;124;165m'; NC=$'\033[0m'
say(){ printf '%s:: %s%s\n' "$CYAN" "$*" "$NC"; }
warn(){ printf '%s!! %s%s\n' "$RED" "$*" "$NC"; }
note(){ printf '%s   %s%s\n' "$DIM" "$*" "$NC"; }

if [[ "$(id -u)" -eq 0 ]]; then warn "do not run as root."; exit 1; fi
if ! command -v pacman &>/dev/null; then warn "this installer targets Arch Linux (pacman)."; exit 1; fi

# ---- AUR helper ----
AUR=""
for h in yay paru; do command -v "$h" &>/dev/null && AUR="$h" && break; done
if [[ -z "$AUR" ]]; then warn "no AUR helper found (yay/paru). install one, then re-run."; exit 1; fi
say "using AUR helper: $AUR"

# ---- confirm ----
cat <<EOF
${CYAN}
  WILL OF THE CITY :: THE INDEX
  This will install Hyprland + lock + bar deps, copy configs to
  ~/.config (existing ones are backed up), and set the wallpaper.
${NC}
EOF
read -rp "proceed? [y/N] " ok; [[ "${ok,,}" == "y" ]] || { note "aborted."; exit 0; }

# ---- packages ----
say "installing repo packages..."
sudo pacman -S --needed --noconfirm \
  hyprland hyprlock hypridle hyprpaper \
  fastfetch qt6-multimedia qt6-svg kitty \
  wofi thunar brightnessctl wireplumber \
  base-devel cmake cpio meson git || warn "some pacman packages failed"

say "installing quickshell (AUR)..."
$AUR -S --needed --noconfirm quickshell-git || warn "quickshell-git failed — install manually for the lock/bar"

# ---- font ----
say "installing Perfect DOS VGA 437..."
mkdir -p "$HOME/.local/share/fonts"
cp "$DIR/assets/PerfectDOSVGA437.ttf" "$HOME/.local/share/fonts/"
fc-cache -f >/dev/null 2>&1 || true

# ---- backup helper ----
TS="$(date +%Y%m%d-%H%M%S)"
BAK="$HOME/.config/.index-backup-$TS"
backup(){ if [[ -e "$1" ]]; then mkdir -p "$BAK"; cp -r "$1" "$BAK/"; note "backed up $(basename "$1") -> $BAK"; fi; }

mkdir -p "$HOME/.config/hypr" "$HOME/.config/quickshell/lock" "$HOME/.config/fastfetch"

# ---- wallpaper + assets ----
say "placing wallpaper + assets..."
cp "$DIR/wallpaper/the-index.png" "$HOME/.config/hypr/wall.png"
rm -rf "$HOME/.config/quickshell/lock/assets"
cp -r "$DIR/assets" "$HOME/.config/quickshell/lock/assets"   # lock.qml reads ./assets

# ---- hypr configs ----
say "installing hypr configs..."
backup "$HOME/.config/hypr/hyprlock.conf";  cp "$DIR/hypr/hyprlock.conf"  "$HOME/.config/hypr/"
backup "$HOME/.config/hypr/hypridle.conf";  cp "$DIR/hypr/hypridle.conf"  "$HOME/.config/hypr/"
# write hyprpaper.conf with ABSOLUTE paths (~ doesn't expand in hyprpaper -> "no target")
backup "$HOME/.config/hypr/hyprpaper.conf"
printf 'preload = %s/.config/hypr/wall.png\nwallpaper = ,%s/.config/hypr/wall.png\nsplash = false\nipc = on\n' "$HOME" "$HOME" > "$HOME/.config/hypr/hyprpaper.conf"
cp "$DIR/hypr/will-of-the-city.conf" "$HOME/.config/hypr/will-of-the-city.conf"

# source the theme from the main config (without clobbering it)
MAIN="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$MAIN" ]]; then
  backup "$MAIN"
  grep -q "will-of-the-city.conf" "$MAIN" || printf '\nsource = ~/.config/hypr/will-of-the-city.conf\n' >> "$MAIN"
  grep -rq "hyprpm reload" "$HOME/.config/hypr/" || printf 'exec-once = hyprpm reload\n' >> "$MAIN"
  note "layered the theme onto your existing hyprland.conf"
else
  cp "$DIR/hypr/hyprland.conf" "$MAIN"
  note "no existing config — installed a FULL base config (terminal=Super+Return, menu=Super+D, lock=Super+L)"
fi

# ---- quickshell: lock + bar + atmosphere ----
say "installing quickshell shell (bar + atmosphere + lock)..."
cp "$DIR/quickshell/shell.qml"      "$HOME/.config/quickshell/"
cp "$DIR/quickshell/Bar.qml"        "$HOME/.config/quickshell/"
cp "$DIR/quickshell/Atmosphere.qml" "$HOME/.config/quickshell/"
cp "$DIR/quickshell/lock/lock.qml"  "$HOME/.config/quickshell/lock/"

# ---- autostart: wallpaper + bar + atmosphere, and KILL conflicting bars ----
say "wiring autostart + removing conflicting bars (noctalia/waybar)..."
SHELL_CMD="quickshell -p $HOME/.config/quickshell/shell.qml"
LUA_AUTO="$HOME/.config/hypr/config/autostart.lua"   # CachyOS-style Lua config
if [[ -f "$LUA_AUTO" ]]; then
  backup "$LUA_AUTO"
  # comment out any 'qs -c noctalia-shell' / waybar autostart (double-bar)
  sed -i 's|^\([^-].*qs -c noctalia-shell.*\)$|-- \1  -- disabled by THE INDEX|' "$LUA_AUTO" || true
  sed -i 's|^\([^-].*exec_cmd("waybar.*\)$|-- \1  -- disabled by THE INDEX|'    "$LUA_AUTO" || true
  if ! grep -q "quickshell -p" "$LUA_AUTO"; then
    printf '\n-- WILL OF THE CITY :: THE INDEX\nhl.exec_cmd("hyprpaper")\nhl.exec_cmd("%s")\n' "$SHELL_CMD" >> "$LUA_AUTO"
  fi
  note "CachyOS Lua config: disabled noctalia, added wallpaper + THE INDEX shell"
elif [[ -f "$MAIN" ]]; then
  grep -q "quickshell -p" "$MAIN" || printf 'exec-once = hyprpaper\nexec-once = %s\n' "$SHELL_CMD" >> "$MAIN"
  note "added wallpaper + shell autostart to hyprland.conf"
fi
# nuke any existing noctalia config so 'qs' can't fall back to it
[[ -d "$HOME/.config/quickshell/noctalia-shell" ]] && { backup "$HOME/.config/quickshell/noctalia-shell"; rm -rf "$HOME/.config/quickshell/noctalia-shell"; } || true


# ---- wofi (themed start-menu launcher, opened by the bar emblem) ----
say "installing themed wofi launcher..."
mkdir -p "$HOME/.config/wofi"
backup "$HOME/.config/wofi/style.css"
cp "$DIR/wofi/config"    "$HOME/.config/wofi/"
cp "$DIR/wofi/style.css" "$HOME/.config/wofi/"
note "if your distro already runs a bar (e.g. CachyOS waybar), disable it to avoid a double bar"

# ---- fastfetch ----
say "installing fastfetch + emblem logo..."
backup "$HOME/.config/fastfetch/config.jsonc"
cp "$DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
cp "$DIR/fastfetch/index.txt"    "$HOME/.config/fastfetch/"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] && { grep -q "^fastfetch" "$rc" || echo "fastfetch" >> "$rc"; }
done

# ---- hyprbars plugin (must run INSIDE a live Hyprland session) ----
say "setting up hyprbars (titlebar buttons)..."
if ! command -v hyprpm &>/dev/null; then
  warn "hyprpm not found — update Hyprland, then add hyprland-plugins manually"
elif [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  warn "not inside a Hyprland session — skipping the hyprbars build."
  note "log into Hyprland, open a terminal there, and run:"
  note "  hyprpm update && hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars && hyprpm reload"
else
  hyprpm update           || warn "hyprpm update failed"
  hyprpm add https://github.com/hyprwm/hyprland-plugins || true
  hyprpm enable hyprbars   || warn "could not enable hyprbars"
  hyprpm reload            || true
fi

# ---- bring it all up NOW if we're inside a live Hyprland session ----
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  say "starting wallpaper + bar + atmosphere..."
  pkill -f noctalia-shell    2>/dev/null || true
  pkill -x waybar            2>/dev/null || true
  pkill -x hyprpaper         2>/dev/null || true
  hyprpaper >/dev/null 2>&1 & disown 2>/dev/null || true
  sleep 1
  pkill -f "quickshell -p $HOME/.config/quickshell/shell.qml" 2>/dev/null || true
  quickshell -p "$HOME/.config/quickshell/shell.qml" >/dev/null 2>&1 & disown 2>/dev/null || true
  note "if the bar didn't appear, run it in the foreground to see errors:"
  note "  quickshell -p ~/.config/quickshell/shell.qml"
fi

# ---- done ----
cat <<EOF

${CYAN}:: done.${NC}
${DIM}   wallpaper ......... set automatically (hyprpaper, absolute path)
   bar + atmosphere .. autostart via quickshell (noctalia/waybar disabled)
   lock screen ....... Super + L  (quickshell THE INDEX lock, wired via hypridle)
   test fastfetch .... fastfetch
   backups ........... $BAK

   If you ran this from a TTY (not inside Hyprland): log into Hyprland and
   everything autostarts. hyprbars (titlebars) only builds inside a live
   session — if it was skipped, just re-run this installer from a terminal
   inside Hyprland.

   The atmosphere + wallpaper are a real Wayland layer — they need a real
   GPU and will NOT render under VirtualBox (use QEMU/virtio-gpu or metal).
   See preview/ for the target look.${NC}

EOF
