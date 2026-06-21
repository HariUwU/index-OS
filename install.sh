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
  fastfetch qt6-multimedia qt6-svg kitty || warn "some pacman packages failed"

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
backup "$HOME/.config/hypr/hyprpaper.conf"; cp "$DIR/hypr/hyprpaper.conf" "$HOME/.config/hypr/"
cp "$DIR/hypr/will-of-the-city.conf" "$HOME/.config/hypr/will-of-the-city.conf"

# source the theme from the main config (without clobbering it)
MAIN="$HOME/.config/hypr/hyprland.conf"
if [[ -f "$MAIN" ]]; then
  backup "$MAIN"
  grep -q "will-of-the-city.conf" "$MAIN" || printf '\nsource = ~/.config/hypr/will-of-the-city.conf\n' >> "$MAIN"
else
  printf 'source = ~/.config/hypr/will-of-the-city.conf\n' > "$MAIN"
  note "no existing hyprland.conf — created a minimal one that sources the theme."
fi

# ---- quickshell lock ----
say "installing quickshell lock..."
cp "$DIR/quickshell/lock/lock.qml" "$HOME/.config/quickshell/lock/"

# ---- fastfetch ----
say "installing fastfetch + emblem logo..."
backup "$HOME/.config/fastfetch/config.jsonc"
cp "$DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
cp "$DIR/fastfetch/index.txt"    "$HOME/.config/fastfetch/"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] && { grep -q "^fastfetch" "$rc" || echo "fastfetch" >> "$rc"; }
done

# ---- hyprbars plugin ----
say "setting up hyprbars (titlebar buttons)..."
if command -v hyprpm &>/dev/null; then
  hyprpm update            || warn "hyprpm update failed (need base-devel + matching headers)"
  hyprpm add https://github.com/hyprwm/hyprland-plugins || true
  hyprpm enable hyprbars    || warn "could not enable hyprbars — run 'hyprpm enable hyprbars' inside a Hyprland session"
  note "ensure your hyprland.conf has:  exec-once = hyprpm reload"
else
  warn "hyprpm not found — update Hyprland, then add hyprland-plugins manually"
fi

# ---- done ----
cat <<EOF

${CYAN}:: done.${NC}
${DIM}   lock screen ....... quickshell -p ~/.config/quickshell/lock/lock.qml
                       (hypridle currently calls hyprlock; edit lock_cmd to
                        switch to the quickshell lock once you've tested it)
   test fastfetch .... fastfetch
   wallpaper ......... ~/.config/hypr/wall.png  (hyprpaper)
   manual lock ....... Super + L
   backups ........... $BAK

   NOTE: the desktop bar / start menu (quickshell taskbar) is the next
   build and is NOT installed yet — only the lock + hyprbars + fastfetch
   + wallpaper are wired. See preview/will-of-the-city-full.html for the
   full intended desktop.${NC}

EOF
