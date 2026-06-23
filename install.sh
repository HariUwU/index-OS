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

cat > "$CFG/labwc/index-lock" <<'LOCKER'
#!/bin/sh
# WILL OF THE CITY :: THE INDEX  —  lock launcher (boot-safe, idempotent)
pgrep -f 'lock/lock.qml' >/dev/null 2>&1 && exit 0
i=0
while [ -z "$WAYLAND_DISPLAY" ] && [ "$i" -lt 30 ]; do sleep 0.2; i=$((i+1)); done
QS="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null)"
[ -z "$QS" ] && exit 1
n=0
while [ "$n" -lt 12 ]; do
  "$QS" -p "$HOME/.config/quickshell/lock/lock.qml" && exit 0
  n=$((n+1)); sleep 0.4
done
exit 1
LOCKER
chmod +x "$CFG/labwc/index-lock"

cat > "$CFG/labwc/autostart" <<'AUTO'
#!/bin/sh
# WILL OF THE CITY :: THE INDEX  —  labwc autostart
LOCKER="$HOME/.config/labwc/index-lock"
# 1) lock FIRST and WAIT until it's actually drawn (no desktop flash)
sh "$LOCKER" &
i=0
while [ "$i" -lt 50 ]; do
  pgrep -f 'lock/lock.qml' >/dev/null 2>&1 && break
  sleep 0.1; i=$((i+1))
done
sleep 0.3
# 2) load wallpaper + bar BEHIND the lock (ready when you unlock)
swaybg -i "$HOME/.config/labwc/wall.png" -m fill &
swayidle -w lock "sh $LOCKER" &
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
# distribute lock assets from the SINGLE source of truth (assets/) — so swapping
# assets/sounds/bg.mp3 (or the font/profile) actually takes effect on the lock.
say "installing lock assets (font, profile, sounds)..."
mkdir -p "$CFG/quickshell/lock/assets/sounds"
cp -f "$DIR/assets/"*.ttf "$DIR/assets/"*.png "$DIR/assets/"*.jpg "$CFG/quickshell/lock/assets/" 2>/dev/null || true
cp -f "$DIR/assets/sounds/"* "$CFG/quickshell/lock/assets/sounds/" 2>/dev/null || true

# ---------- 6. launcher + fastfetch ----------
mkdir -p "$CFG/wofi" "$CFG/fastfetch"
cp -f "$DIR/wofi/config" "$CFG/wofi/" 2>/dev/null || true
cp -f "$DIR/wofi/style.css" "$CFG/wofi/" 2>/dev/null || true
cp -rf "$DIR/fastfetch/." "$CFG/fastfetch/" 2>/dev/null || true

# ---------- 7. auto-start labwc on login (TTY1), silently ----------
say "setting labwc to start on login (silent)..."
BP="$HOME/.bash_profile"; SNIP_B='[ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && { clear; exec dbus-run-session labwc >/dev/null 2>&1; }'
touch "$BP"; grep -q "exec dbus-run-session labwc" "$BP" 2>/dev/null || printf '\n# WILL OF THE CITY :: THE INDEX\n%s\n' "$SNIP_B" >> "$BP"
FC="$HOME/.config/fish/config.fish"; mkdir -p "$(dirname "$FC")"; touch "$FC"
if ! grep -q "dbus-run-session labwc" "$FC" 2>/dev/null; then
  cat >> "$FC" <<'FISH'

# WILL OF THE CITY :: THE INDEX
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    clear
    exec dbus-run-session labwc >/dev/null 2>&1
end
FISH
fi

# ---------- 7b. TTY1 AUTOLOGIN -> boot straight into labwc + INDEX lock ----------
# no text password at boot; the INDEX lock becomes the only auth gate.
say "enabling tty1 autologin (boot straight into the INDEX lock)..."
USERNAME="$(id -un)"
AGETTY="$(command -v agetty 2>/dev/null || echo /usr/bin/agetty)"
if command -v systemctl >/dev/null 2>&1; then
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  printf '[Service]\nExecStart=\nExecStart=-%s --autologin %s --noclear %%I $TERM\nType=idle\n' "$AGETTY" "$USERNAME" \
    | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
  sudo systemctl daemon-reload 2>/dev/null || true
  sudo systemctl enable getty@tty1.service 2>/dev/null || true
  if sudo test -f /etc/systemd/system/getty@tty1.service.d/autologin.conf; then
    note "tty1 autologin set for '$USERNAME' -> boots straight to labwc + INDEX lock"
  else
    note "autologin file did NOT write — re-run with sudo available"
  fi
else
  note "no systemd — set up tty1 autologin manually"
fi

# hush the getty login banner (no "<host> login:" flash)
sudo touch /etc/issue 2>/dev/null && sudo cp /etc/issue /etc/issue.index-bak 2>/dev/null && echo -n "" | sudo tee /etc/issue >/dev/null 2>&1 || true

# ---------- 7c. SILENT BOOT (quiet kernel messages) ----------
# best-effort: hides kernel/systemd boot text. Backs up before touching anything.
say "quieting boot messages (silent boot)..."
QUIET="quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0"
if [ -d /boot/loader/entries ]; then           # systemd-boot
  for e in /boot/loader/entries/*.conf; do
    [ -f "$e" ] || continue
    grep -q "loglevel=3" "$e" 2>/dev/null && continue
    sudo cp "$e" "$e.index-bak" 2>/dev/null || true
    sudo sed -i "s/^\(options .*\)$/\1 $QUIET/" "$e" 2>/dev/null || true
  done
  note "systemd-boot: added quiet params (backups: *.index-bak)"
elif [ -f /etc/default/grub ]; then            # GRUB
  if ! grep -q "loglevel=3" /etc/default/grub; then
    sudo cp /etc/default/grub /etc/default/grub.index-bak 2>/dev/null || true
    sudo sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $QUIET\"/" /etc/default/grub 2>/dev/null || true
    if command -v grub-mkconfig >/dev/null; then sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true; fi
  fi
  note "GRUB: added quiet params (backup: /etc/default/grub.index-bak)"
else
  note "unknown bootloader — skipped quiet params (boot text will still show)"
fi

# ---------- 8. VERIFY everything landed ----------
echo; say "verifying install:"
chk(){ [ -s "$1" ] && ok "$2" || bad "$2  (MISSING: $1)"; }
chk "$CFG/labwc/rc.xml"                          "labwc rc.xml"
chk "$CFG/labwc/autostart"                       "labwc autostart"
chk "$CFG/labwc/index-lock"                      "lock launcher (boot-safe)"
chk "$CFG/labwc/wall.png"                        "wallpaper"
chk "$THEMES/the-index/labwc/themerc"            "titlebar themerc"
chk "$THEMES/the-index/labwc/close-active.png"   "bracket button [X]"
chk "$THEMES/the-index/labwc/iconify-active.png" "bracket button [_]"
chk "$THEMES/the-index/labwc/max-active.png"     "bracket button [#]"
chk "$CFG/quickshell/shell.qml"                  "quickshell shell"
chk "$CFG/quickshell/Bar.qml"                    "bar"
chk "$CFG/quickshell/Atmosphere.qml"             "atmosphere"
chk "$CFG/quickshell/lock/lock.qml"              "INDEX lock"
sudo test -f /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null && ok "tty1 autologin (no text login)" || bad "tty1 autologin NOT set"
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
