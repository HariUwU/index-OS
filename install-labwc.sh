#!/usr/bin/env bash
# ============================================================
#  WILL OF THE CITY :: THE INDEX  —  labwc installer
#  The reason this exists: labwc draws titlebar buttons from
#  IMAGE files, so the [_] [#] [X] bracket buttons from the
#  preview are REAL here (Hyprland's hyprbars can't do that).
#  quickshell bar/atmosphere/lock + wallpaper carry over.
# ============================================================
set -euo pipefail
CYAN=$'\e[38;2;93;173;226m'; DIM=$'\e[2m'; RED=$'\e[38;2;255;107;107m'; NC=$'\e[0m'
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say(){ printf '%s::%s %s\n' "$CYAN" "$NC" "$1"; }
note(){ printf '   %s%s%s\n' "$DIM" "$1" "$NC"; }
warn(){ printf '%s!!%s %s\n' "$RED" "$NC" "$1"; }
TS="$(date +%s)"; BAK="$HOME/.config/.index-backup-$TS"
backup(){ [ -e "$1" ] && { mkdir -p "$BAK"; cp -a "$1" "$BAK"/ 2>/dev/null || true; } ; }

say "WILL OF THE CITY :: THE INDEX  (labwc edition)"

# ---- packages ----
if command -v pacman >/dev/null; then
  say "installing packages..."
  sudo pacman -S --needed --noconfirm labwc swaybg swayidle foot wofi wtype thunar \
      qt6-multimedia qt6-svg fastfetch wireplumber brightnessctl \
      base-devel cmake meson git || warn "some packages failed (continuing)"
  if ! command -v quickshell >/dev/null && ! command -v qs >/dev/null; then
    if command -v yay >/dev/null; then yay -S --needed --noconfirm quickshell-git || warn "quickshell-git failed"
    else warn "install an AUR helper (yay) then: yay -S quickshell-git"; fi
  fi
else
  warn "not an Arch system — install manually: labwc swaybg foot wofi quickshell qt6-multimedia qt6-svg fastfetch"
fi

# ---- font ----
say "installing Perfect DOS VGA 437..."
mkdir -p "$HOME/.local/share/fonts"
cp "$DIR/assets/PerfectDOSVGA437.ttf" "$HOME/.local/share/fonts/" 2>/dev/null || cp "$DIR/fastfetch/"*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true

# ---- labwc theme (the bracket-button titlebar) ----
say "installing THE INDEX titlebar theme..."
mkdir -p "$HOME/.local/share/themes/the-index/labwc"
backup "$HOME/.local/share/themes/the-index/labwc"
cp "$DIR/labwc/theme/the-index/labwc/"* "$HOME/.local/share/themes/the-index/labwc/"

# ---- labwc config ----
say "installing labwc config..."
mkdir -p "$HOME/.config/labwc"
for f in rc.xml menu.xml autostart environment; do
  backup "$HOME/.config/labwc/$f"; cp "$DIR/labwc/config/$f" "$HOME/.config/labwc/$f"
done
chmod +x "$HOME/.config/labwc/autostart"

# ---- wallpaper ----
say "installing wallpaper..."
cp "$DIR/wallpaper/the-index.png" "$HOME/.config/labwc/wall.png"

# ---- quickshell: bar + atmosphere + lock ----
say "installing quickshell shell (bar + atmosphere + lock)..."
mkdir -p "$HOME/.config/quickshell/Bar" "$HOME/.config/quickshell/Atmosphere" "$HOME/.config/quickshell/lock"
cp -r "$DIR/quickshell/." "$HOME/.config/quickshell/"

# ---- wofi + fastfetch ----
mkdir -p "$HOME/.config/wofi" "$HOME/.config/fastfetch"
cp "$DIR/wofi/config" "$HOME/.config/wofi/" 2>/dev/null || true
cp "$DIR/wofi/style.css" "$HOME/.config/wofi/" 2>/dev/null || true
cp -r "$DIR/fastfetch/." "$HOME/.config/fastfetch/" 2>/dev/null || true

cat <<DONE

${CYAN}:: done. (labwc edition)${NC}
${DIM}   start it from a TTY:   dbus-run-session labwc
   titlebar buttons .. [_] [#] [X]  (real bracket glyphs, the preview look)
   terminal .......... Super + Return  (foot)
   launcher .......... Super + D       (wofi)
   close window ...... Super + Q
   lock (INDEX) ...... DEFAULT lock — Super+L AND loginctl lock-session
                       both run the INDEX lock; NO idle auto-lock
   wallpaper + bar ... start via ~/.config/labwc/autostart

   HONEST NOTES:
   - The bracket TITLEBARS are the guaranteed win here — they're pure labwc
     and will look like the preview.
   - The bar's workspace pills read Hyprland's IPC, so on labwc they may be
     empty; the clock/date/emblem/atmosphere/wallpaper still work. If the
     whole bar fails to load, run it in the foreground to see the error:
        quickshell -p ~/.config/quickshell/shell.qml
     and send it to me — we'll swap the Hyprland bits for labwc's.
   - Needs a real GPU path (QEMU/virtio-gpu or metal), not VirtualBox.
   backups ........... $BAK${NC}
DONE
