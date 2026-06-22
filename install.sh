#!/usr/bin/env bash
# ============================================================
#  WILL OF THE CITY :: THE INDEX  —  labwc  (plug & play)
#  Wipes any half-installed state, lays everything down,
#  GENERATES the fragile files (so they can't copy-corrupt),
#  verifies every file, and sets labwc to boot automatically.
#  Safe to re-run any time.
# ============================================================
CYAN=$'\e[38;2;93;173;226m'; DIM=$'\e[2m'; RED=$'\e[38;2;255;107;107m'; GRN=$'\e[38;2;93;226;133m'; NC=$'\e[0m'
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say(){ printf '%s::%s %s\n' "$CYAN" "$NC" "$1"; }
ok(){  printf '   %s\xe2\x9c\x93%s %s\n' "$GRN" "$NC" "$1"; }
bad(){ printf '   %s\xe2\x9c\x97%s %s\n' "$RED" "$NC" "$1"; }
note(){ printf '   %s%s%s\n' "$DIM" "$1" "$NC"; }
CFG="$HOME/.config"; THEMES="$HOME/.local/share/themes"

say "WILL OF THE CITY :: THE INDEX  —  labwc (plug & play)"
[ -d "$DIR/labwc" ] || { bad "run this from inside the index-OS repo (labwc/ not found)"; exit 1; }

# ---------- 1. packages ----------
if command -v pacman >/dev/null; then
  say "installing packages..."
  sudo pacman -S --needed --noconfirm \
      labwc swaybg swayidle foot wofi wtype thunar \
      qt6-multimedia qt6-svg qt6-declarative fastfetch wireplumber \
      brightnessctl ttf-dejavu base-devel cmake meson git 2>/dev/null \
      || note "(some packages may have failed - continuing)"
  if ! command -v quickshell >/dev/null && ! command -v qs >/dev/null; then
    say "installing quickshell (AUR)..."
    if command -v yay >/dev/null; then yay -S --needed --noconfirm quickshell-git || note "quickshell-git failed"
    elif command -v paru >/dev/null; then paru -S --needed --noconfirm quickshell-git || note "quickshell-git failed"
    else note "no AUR helper - install yay then: yay -S quickshell-git"; fi
  fi
else
  note "not Arch - install manually: labwc swaybg swayidle foot wofi wtype quickshell qt6-multimedia qt6-svg fastfetch"
fi

# ---------- 2. font ----------
say "installing Perfect DOS VGA 437..."
mkdir -p "$HOME/.local/share/fonts"
cp -f "$DIR/assets/PerfectDOSVGA437.ttf" "$HOME/.local/share/fonts/" 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true

# ---------- 3. titlebar theme (the bracket buttons) ----------
say "installing THE INDEX titlebar theme..."
rm -rf "$THEMES/the-index"
mkdir -p "$THEMES/the-index/labwc"
cp -f "$DIR"/labwc/theme/the-index/labwc/* "$THEMES/the-index/labwc/" 2>/dev/null

# ---------- 4. labwc config (rc/menu copied, autostart/env GENERATED) ----------
say "writing labwc config..."
rm -rf "$CFG/labwc"; mkdir -p "$CFG/labwc"
cp -f "$DIR/labwc/config/rc.xml"   "$CFG/labwc/rc.xml"
cp -f "$DIR/labwc/config/menu.xml" "$CFG/labwc/menu.xml"
cp -f "$DIR/wallpaper/the-index.png" "$CFG/labwc/wall.png"

cat > "$CFG/labwc/autostart" <<'AUTO'
#!/bin/sh
# WILL OF THE CITY :: THE INDEX  —  labwc autostart
LOCK='pgrep -f lock/lock.qml || quickshell -p $HOME/.config/quickshell/lock/lock.qml'
swaybg -i "$HOME/.config/labwc/wall.png" -m fill &
swayidle -w lock "$LOCK" &
quickshell -p "$HOME/.config/quickshell/shell.qml" &
AUTO
chmod +x "$CFG/labwc/autostart"

cat > "$CFG/labwc/environment" <<'ENVF'
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=24
QT_QPA_PLATFORM=wayland
ENVF

# ---------- 5. quickshell shell (bar + atmosphere + lock) ----------
say "installing quickshell shell..."
rm -rf "$CFG/quickshell"; mkdir -p "$CFG/quickshell"
cp -rf "$DIR/quickshell/." "$CFG/quickshell/"

# ---------- 6. launcher + fastfetch ----------
mkdir -p "$CFG/wofi" "$CFG/fastfetch"
cp -f "$DIR/wofi/config" "$CFG/wofi/" 2>/dev/null || true
cp -f "$DIR/wofi/style.css" "$CFG/wofi/" 2>/dev/null || true
cp -rf "$DIR/fastfetch/." "$CFG/fastfetch/" 2>/dev/null || true

# ---------- 7. auto-start labwc on login (TTY1) ----------
say "setting labwc to start on login..."
BP="$HOME/.bash_profile"; SNIP_B='[ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && exec dbus-run-session labwc'
touch "$BP"; grep -q "exec dbus-run-session labwc" "$BP" 2>/dev/null || printf '\n# WILL OF THE CITY :: THE INDEX\n%s\n' "$SNIP_B" >> "$BP"
FC="$HOME/.config/fish/config.fish"; mkdir -p "$(dirname "$FC")"; touch "$FC"
if ! grep -q "dbus-run-session labwc" "$FC" 2>/dev/null; then
  cat >> "$FC" <<'FISH'

# WILL OF THE CITY :: THE INDEX
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    exec dbus-run-session labwc
end
FISH
fi

# ---------- 8. VERIFY everything landed ----------
echo; say "verifying install:"
chk(){ [ -s "$1" ] && ok "$2" || bad "$2  (MISSING: $1)"; }
chk "$CFG/labwc/rc.xml"                          "labwc rc.xml"
chk "$CFG/labwc/autostart"                       "labwc autostart"
chk "$CFG/labwc/wall.png"                        "wallpaper"
chk "$THEMES/the-index/labwc/themerc"            "titlebar themerc"
chk "$THEMES/the-index/labwc/close-active.png"   "bracket button [X]"
chk "$THEMES/the-index/labwc/iconify-active.png" "bracket button [_]"
chk "$THEMES/the-index/labwc/max-active.png"     "bracket button [#]"
chk "$CFG/quickshell/shell.qml"                  "quickshell shell"
chk "$CFG/quickshell/Bar.qml"                    "bar"
chk "$CFG/quickshell/Atmosphere.qml"             "atmosphere"
chk "$CFG/quickshell/lock/lock.qml"              "INDEX lock"
command -v labwc  >/dev/null && ok "labwc installed"  || bad "labwc NOT installed"
( command -v quickshell >/dev/null || command -v qs >/dev/null ) && ok "quickshell installed" || bad "quickshell NOT installed - run: yay -S quickshell-git"
command -v swaybg >/dev/null && ok "swaybg installed" || bad "swaybg NOT installed"

cat <<DONE

${CYAN}:: done.${NC}
${DIM}   Reboot, or from TTY1 run:  dbus-run-session labwc
   (it now starts automatically when you log in on tty1.)

   Inside labwc:
     Super+Return  terminal      Super+D  launcher
     Super+Q       close         Super+L  INDEX lock (default)
     Super+1..5    desktops      right-click  menu

   If a line above shows a red X, that one thing is missing - tell me which.
   If the bar doesn't appear, run this and send me the output:
     quickshell -p ~/.config/quickshell/shell.qml${NC}
DONE
