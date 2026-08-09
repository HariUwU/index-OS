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

# ---------- 1. packages (multi-distro: pacman / apt / dnf / zypper) ----------
say "detecting distro + installing packages..."
PKG=""
command -v pacman >/dev/null && PKG=pacman
command -v apt-get >/dev/null && PKG=apt
command -v dnf >/dev/null && PKG=dnf
command -v zypper >/dev/null && PKG=zypper

case "$PKG" in
  pacman)
    sudo pacman -S --needed --noconfirm \
        labwc swaybg swayidle foot wofi wtype thunar thunar-archive-plugin thunar-volman xarchiver file-roller cups cups-pdf system-config-printer grim slurp wl-clipboard libnotify playerctl blueman networkmanager fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt xdg-desktop-portal xdg-desktop-portal-wlr pipewire pipewire-pulse wlopm gammastep pavucontrol wlr-randr nwg-displays swappy \
        cliphist udiskie wlopm gvfs udisks2 tumbler ffmpegthumbnailer thunar-archive-plugin xarchiver noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation \
        qt6-multimedia qt6-svg qt6-declarative fastfetch wireplumber ffmpeg gst-libav gst-plugins-good \
        brightnessctl upower wlopm ttf-dejavu noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra gnome-themes-extra qt6ct qt5ct polkit-gnome xorg-xwayland cliphist udiskie xdg-utils xdg-user-dirs dex flatpak gvfs gvfs-mtp tumbler base-devel cmake meson git 2>/dev/null \
        || note "(some packages failed - continuing)"
    ;;
  apt)
    sudo apt-get update -y 2>/dev/null || true
    sudo apt-get install -y \
        labwc swaybg swayidle foot wofi wtype thunar thunar-archive-plugin thunar-volman xarchiver file-roller cups cups-pdf system-config-printer grim slurp wl-clipboard libnotify playerctl blueman networkmanager fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt xdg-desktop-portal xdg-desktop-portal-wlr pipewire pipewire-pulse wlopm gammastep pavucontrol wlr-randr nwg-displays swappy \
        cliphist udiskie wlopm gvfs udisks2 tumbler ffmpegthumbnailer thunar-archive-plugin xarchiver noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation \
        qt6-multimedia-dev libqt6svg6 qml6-module-qtquick fastfetch wireplumber ffmpeg gstreamer1.0-libav \
        brightnessctl upower fonts-dejavu fonts-noto fonts-noto-cjk fonts-noto-color-emoji cups printer-driver-all system-config-printer gnome-themes-extra qt6ct policykit-1-gnome xwayland wl-clipboard udiskie xdg-utils xdg-user-dirs dex flatpak gvfs gvfs-backends cmake meson ninja-build build-essential git \
        2>/dev/null || note "(some apt packages failed - continuing)"
    ;;
  dnf)
    sudo dnf install -y \
        labwc swaybg swayidle foot wofi wtype thunar thunar-archive-plugin thunar-volman xarchiver file-roller cups cups-pdf system-config-printer grim slurp wl-clipboard libnotify playerctl blueman networkmanager fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt xdg-desktop-portal xdg-desktop-portal-wlr pipewire pipewire-pulse wlopm gammastep pavucontrol wlr-randr nwg-displays swappy \
        cliphist udiskie wlopm gvfs udisks2 tumbler ffmpegthumbnailer thunar-archive-plugin xarchiver noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation \
        qt6-qtmultimedia qt6-qtsvg qt6-qtdeclarative fastfetch wireplumber ffmpeg \
        brightnessctl upower dejavu-sans-fonts google-noto-sans-fonts google-noto-sans-cjk-fonts google-noto-emoji-color-fonts cups system-config-printer gnome-themes-extra qt6ct polkit-gnome xorg-x11-server-Xwayland udiskie xdg-utils xdg-user-dirs dex flatpak gvfs cmake meson ninja-build gcc-c++ git \
        2>/dev/null || note "(some dnf packages failed - continuing)"
    ;;
  zypper)
    sudo zypper --non-interactive install \
        labwc swaybg swayidle foot wofi wtype thunar thunar-archive-plugin thunar-volman xarchiver file-roller cups cups-pdf system-config-printer grim slurp wl-clipboard libnotify playerctl blueman networkmanager fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt xdg-desktop-portal xdg-desktop-portal-wlr pipewire pipewire-pulse wlopm gammastep pavucontrol wlr-randr nwg-displays swappy \
        cliphist udiskie wlopm gvfs udisks2 tumbler ffmpegthumbnailer thunar-archive-plugin xarchiver noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation \
        qt6-multimedia-imports qt6-svg qt6-declarative-imports fastfetch wireplumber ffmpeg \
        brightnessctl upower dejavu-fonts noto-sans-fonts noto-sans-cjk-fonts noto-coloremoji-fonts cups system-config-printer gnome-themes-extra qt6ct polkit-gnome xwayland udiskie xdg-utils xdg-user-dirs dex flatpak gvfs cmake meson ninja gcc-c++ git \
        2>/dev/null || note "(some zypper packages failed - continuing)"
    ;;
  *)
    note "unknown distro/package manager — install manually: labwc swaybg swayidle foot wofi wtype quickshell qt6-multimedia qt6-svg fastfetch ffmpeg" ;;
esac

# quickshell: packaged on Arch (AUR); build from source elsewhere
if ! command -v quickshell >/dev/null && ! command -v qs >/dev/null; then
  if [ "$PKG" = "pacman" ]; then
    say "installing quickshell (AUR)..."
    if   command -v yay  >/dev/null; then yay  -S --needed --noconfirm quickshell-git || note "quickshell-git failed"
    elif command -v paru >/dev/null; then paru -S --needed --noconfirm quickshell-git || note "quickshell-git failed"
    else note "no AUR helper - install yay then: yay -S quickshell-git"; fi
  else
    say "quickshell not packaged here — building from source (slow)..."
    # build deps per distro
    case "$PKG" in
      apt)    sudo apt-get install -y qt6-base-dev qt6-declarative-dev qt6-wayland-dev libwayland-dev wayland-protocols libpam0g-dev libjemalloc-dev libpipewire-0.3-dev cli11-dev 2>/dev/null || true ;;
      dnf)    sudo dnf install -y qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel wayland-devel wayland-protocols-devel pam-devel jemalloc-devel pipewire-devel cli11-devel 2>/dev/null || true ;;
      zypper) sudo zypper --non-interactive install qt6-base-devel qt6-declarative-devel qt6-wayland-devel wayland-devel wayland-protocols-devel pam-devel jemalloc-devel pipewire-devel 2>/dev/null || true ;;
    esac
    TMPQ="$(mktemp -d)"
    if git clone --depth 1 https://github.com/quickshell-mirror/quickshell "$TMPQ" 2>/dev/null \
       && cmake -S "$TMPQ" -B "$TMPQ/build" -GNinja -DCMAKE_BUILD_TYPE=Release 2>/dev/null \
       && cmake --build "$TMPQ/build" 2>/dev/null \
       && sudo cmake --install "$TMPQ/build" 2>/dev/null; then
      note "quickshell built + installed from source"
    else
      note "quickshell source build FAILED — see https://quickshell.outfoxxed.me/docs/guide/install/ for your distro"
    fi
    rm -rf "$TMPQ"
  fi
fi

# ---------- 1b. flatpak + flathub ----------
if command -v flatpak >/dev/null 2>&1; then
  say "adding flathub remote..."
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
    && note "flathub added (system-wide)" || note "flathub remote-add failed"
  # an app store GUI for browsing flathub
  case "$PKG" in
    pacman) sudo pacman -S --needed --noconfirm gnome-software 2>/dev/null || true ;;
    apt)    sudo apt-get install -y gnome-software gnome-software-plugin-flatpak 2>/dev/null || true ;;
    dnf)    sudo dnf install -y gnome-software 2>/dev/null || true ;;
    zypper) sudo zypper --non-interactive install gnome-software 2>/dev/null || true ;;
  esac
  # Bazaar: lightweight Flathub app store (~12MiB), ships as a flatpak itself
  if ! flatpak info io.github.kolunmi.Bazaar >/dev/null 2>&1; then
    say "installing Bazaar (Flathub app store)..."
    sudo flatpak install -y --noninteractive flathub io.github.kolunmi.Bazaar 2>/dev/null \
      && note "Bazaar installed — browse Flathub from the launcher" \
      || note "Bazaar install failed (check network / flathub remote)"
  else
    note "Bazaar already installed"
  fi

  # portals so flatpak apps can open files / use the desktop properly on wlroots
  case "$PKG" in
    pacman) sudo pacman -S --needed --noconfirm xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk 2>/dev/null || true ;;
    apt)    sudo apt-get install -y xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk 2>/dev/null || true ;;
    dnf)    sudo dnf install -y xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk 2>/dev/null || true ;;
    zypper) sudo zypper --non-interactive install xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk 2>/dev/null || true ;;
  esac
fi

# printing: enable CUPS so printers can be added from settings
command -v systemctl >/dev/null 2>&1 && sudo systemctl enable --now cups.service 2>/dev/null || true

# ---------- 2. font ----------
say "installing Perfect DOS VGA 437..."
mkdir -p "$HOME/.local/share/fonts"
cp -f "$DIR/assets/"*.ttf "$DIR/assets/"*.otf "$HOME/.local/share/fonts/" 2>/dev/null || true
for f in "$DIR/assets/"*.ttf "$DIR/assets/"*.otf; do [ -f "$f" ] && note "font: $(basename "$f")"; done
# pixel fonts for other scripts (CJK / Cyrillic / Greek / Hangul)
if [ "$PKG" = "pacman" ]; then
  if command -v yay >/dev/null; then yay -S --needed --noconfirm ark-pixel-font-12px-monospaced 2>/dev/null || note "ark-pixel (AUR) skipped"
  elif command -v paru >/dev/null; then paru -S --needed --noconfirm ark-pixel-font-12px-monospaced 2>/dev/null || note "ark-pixel (AUR) skipped"; fi
fi
# LanaPixel: Latin/Greek/Cyrillic/Hangul + some CJK, drop it in assets/ to have it installed
[ -f "$DIR/assets/LanaPixel.ttf" ] && cp -f "$DIR/assets/LanaPixel.ttf" "$HOME/.local/share/fonts/" 2>/dev/null || true

fc-cache -f >/dev/null 2>&1 || true
mkdir -p "$CFG/fontconfig"
cp -f "$DIR/labwc/config/fontconfig/fonts.conf" "$CFG/fontconfig/fonts.conf" 2>/dev/null || true
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
[ -f "$DIR/labwc/config/index.conf" ] && cp -f "$DIR/labwc/config/index.conf" "$CFG/labwc/index.conf" 2>/dev/null || true

cp -f "$DIR/labwc/config/index-lock" "$CFG/labwc/index-lock"
chmod +x "$CFG/labwc/index-lock"

cp -f "$DIR/labwc/config/index-logout" "$CFG/labwc/index-logout"
chmod +x "$CFG/labwc/index-logout"
cp -f "$DIR/labwc/config/index-display-save" "$CFG/labwc/index-display-save" 2>/dev/null || true
cp -f "$DIR/labwc/config/index-display-restore" "$CFG/labwc/index-display-restore" 2>/dev/null || true
chmod +x "$CFG/labwc/index-display-save" "$CFG/labwc/index-display-restore" 2>/dev/null || true
cp -f "$DIR/labwc/config/index-idle" "$CFG/labwc/index-idle" 2>/dev/null || true
cp -f "$DIR/labwc/config/index-input" "$CFG/labwc/index-input" 2>/dev/null || true
cp -f "$DIR/labwc/config/index-clip" "$CFG/labwc/index-clip" 2>/dev/null || true
chmod +x "$CFG/labwc/index-clip" 2>/dev/null || true

# PRESCRIPT word bank is bundled directly in quickshell/prescript.json.
chmod +x "$CFG/labwc/index-input" 2>/dev/null || true

# Thai input method configs (Super+Space switches EN/TH)
mkdir -p "$CFG/fcitx5/conf"
[ -f "$CFG/fcitx5/profile" ] || cp -f "$DIR/labwc/config/fcitx5-profile" "$CFG/fcitx5/profile" 2>/dev/null || true
[ -f "$CFG/fcitx5/config" ]  || cp -f "$DIR/labwc/config/fcitx5-config"  "$CFG/fcitx5/config"  2>/dev/null || true
chmod +x "$CFG/labwc/index-idle" 2>/dev/null || true


# copy the real autostart (lock, desktop, polkit, clipboard, idle, XDG apps, fcitx5)
cp -f "$DIR/labwc/config/autostart" "$CFG/labwc/autostart"
chmod +x "$CFG/labwc/autostart"

# copy the real environment file (cursor, GTK/Qt theming, CSD, XKB layouts)
cp -f "$DIR/labwc/config/environment" "$CFG/labwc/environment"

# ---------- 5. quickshell shell (bar + atmosphere + lock) ----------
say "installing quickshell shell..."
# preserve a previously-installed boot video across the wipe below
SAVED_VID=""
if [ -f "$CFG/quickshell/lock/assets/intro.mp4" ]; then
  SAVED_VID="/tmp/.index-intro-saved.mp4"; cp -f "$CFG/quickshell/lock/assets/intro.mp4" "$SAVED_VID" 2>/dev/null || true
fi
rm -rf "$CFG/quickshell"; mkdir -p "$CFG/quickshell"
cp -rf "$DIR/quickshell/." "$CFG/quickshell/"
[ -f "$CFG/quickshell/prescript.json" ] && note "Prescript JSON installed" || note "Prescript JSON missing"
# distribute lock assets from the SINGLE source of truth (assets/) — so swapping
# assets/sounds/bg.mp3 (or the font/profile) actually takes effect on the lock.
say "installing lock assets (font, profile, sounds)..."
mkdir -p "$CFG/quickshell/lock/assets/sounds"
cp -f "$DIR/assets/"*.ttf "$DIR/assets/"*.png "$DIR/assets/"*.jpg "$CFG/quickshell/lock/assets/" 2>/dev/null || true
cp -f "$DIR/assets/sounds/"* "$CFG/quickshell/lock/assets/sounds/" 2>/dev/null || true
# UI sound effects for the shell (notify / tick / connect / disconnect / menu / error)
mkdir -p "$CFG/quickshell/assets/sounds/ui"
cp -f "$DIR/assets/sounds/ui/"*.wav "$DIR/assets/sounds/ui/"*.mp3 "$CFG/quickshell/assets/sounds/ui/" 2>/dev/null || true

# OPTIONAL local boot video — find intro.mp4 wherever you put it; replace if present, else keep any saved one
DEST_VID="$CFG/quickshell/lock/assets/intro.mp4"
VID_SRC=""
for c in \
  "$DIR/assets/intro.mp4" \
  "$DIR/intro.mp4" \
  "$DIR/quickshell/lock/assets/intro.mp4" \
  "$HOME/index-OS/assets/intro.mp4" \
  "$HOME/intro.mp4" \
  "$HOME/Videos/intro.mp4" \
  "$HOME/Downloads/intro.mp4" ; do
  [ -f "$c" ] && { VID_SRC="$c"; break; }
done
if [ -n "$VID_SRC" ]; then
  cp -f "$VID_SRC" "$DEST_VID" 2>/dev/null && say "boot video installed from: $VID_SRC"
elif [ -n "$SAVED_VID" ] && [ -f "$SAVED_VID" ]; then
  cp -f "$SAVED_VID" "$DEST_VID" 2>/dev/null && note "kept your existing boot video"
else
  note "no intro.mp4 found — boot goes straight to the lock (drop one at ~/index-OS/assets/intro.mp4 and re-run)"
fi
rm -f "$SAVED_VID" 2>/dev/null || true

# ADAPTIVE: if the GPU is software/virtio (no real accel), downscale the video to 720p30
# so it doesn't freeze. On real hardware the full-quality file is kept untouched.
if [ -f "$DEST_VID" ]; then
  SOFTGPU=0
  if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qiE 'virtio|qxl|vga.*(cirrus|bochs|vmware)'; then SOFTGPU=1; fi
  grep -qiE 'virtio|llvmpipe|software' /sys/class/drm/*/device/uevent 2>/dev/null && SOFTGPU=1
  [ -e /dev/dri/renderD128 ] || SOFTGPU=1   # no render node = no accel
  if [ "$SOFTGPU" = "1" ] && command -v ffmpeg >/dev/null 2>&1; then
    say "software/virtio GPU detected — transcoding boot video to 720p30 (smooth in VM)..."
    if ffmpeg -y -i "$DEST_VID" -vf "scale=-2:720" -r 30 -c:v libx264 -preset veryfast -crf 24 -c:a aac "$DEST_VID.vm.mp4" >/dev/null 2>&1; then
      mv -f "$DEST_VID.vm.mp4" "$DEST_VID" && note "boot video downscaled for smooth software-render playback"
    else
      rm -f "$DEST_VID.vm.mp4" 2>/dev/null; note "transcode failed — keeping original (may stutter in VM; install ffmpeg)"
    fi
  elif [ "$SOFTGPU" = "1" ]; then
    note "software GPU but no ffmpeg — video may freeze in VM. install ffmpeg + re-run to auto-downscale"
  fi
fi

# ---------- 6. launcher + fastfetch + foot + dark theme ----------
mkdir -p "$CFG/wofi" "$CFG/fastfetch"
cp -f "$DIR/wofi/config" "$CFG/wofi/" 2>/dev/null || true
cp -f "$DIR/wofi/style.css" "$CFG/wofi/" 2>/dev/null || true
cp -rf "$DIR/fastfetch/." "$CFG/fastfetch/" 2>/dev/null || true

# foot terminal — THE INDEX cyan CRT theme
say "theming foot + forcing dark on apps..."
mkdir -p "$CFG/foot"
if cp -f "$DIR/labwc/config/foot.ini" "$CFG/foot/foot.ini" 2>/dev/null; then
  note "Foot config installed (130x40)"
else
  note "Foot config install failed"
fi

# GTK 3/4 — the INDEX-cyan theme so apps (Thunar, dialogs, pavucontrol) match the desktop
mkdir -p "$THEMES/the-index/gtk-3.0" "$THEMES/the-index/gtk-4.0"
cp -f "$DIR/labwc/theme/the-index-gtk/gtk-3.0/gtk.css" "$THEMES/the-index/gtk-3.0/gtk.css" 2>/dev/null || true
cp -f "$DIR/labwc/theme/the-index-gtk/gtk-4.0/gtk.css" "$THEMES/the-index/gtk-4.0/gtk.css" 2>/dev/null || true
cp -f "$DIR/labwc/theme/the-index-gtk/index.theme" "$THEMES/the-index/index.theme" 2>/dev/null || true
# direct config override = strongest (applies over any theme, incl. libadwaita apps)
mkdir -p "$CFG/gtk-3.0" "$CFG/gtk-4.0"
cp -f "$DIR/labwc/config/gtk/settings.ini" "$CFG/gtk-3.0/settings.ini" 2>/dev/null || true
cp -f "$DIR/labwc/config/gtk/settings.ini" "$CFG/gtk-4.0/settings.ini" 2>/dev/null || true
cp -f "$DIR/labwc/theme/the-index-gtk/gtk-3.0/gtk.css" "$CFG/gtk-3.0/gtk.css" 2>/dev/null || true
cp -f "$DIR/labwc/theme/the-index-gtk/gtk-4.0/gtk.css" "$CFG/gtk-4.0/gtk.css" 2>/dev/null || true
command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface gtk-theme 'the-index' 2>/dev/null || true
command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.wm.preferences button-layout ':' 2>/dev/null || true

# screen sharing — xdg-desktop-portal needs to know labwc uses the wlr backend
say "configuring screen share portal..."
mkdir -p "$CFG/xdg-desktop-portal" "$CFG/xdg-desktop-portal/wlr"
cp -f "$DIR/labwc/config/portal/labwc-portals.conf" "$CFG/xdg-desktop-portal/labwc-portals.conf" 2>/dev/null || true
cp -f "$DIR/labwc/config/portal/wlr.conf" "$CFG/xdg-desktop-portal/wlr/config" 2>/dev/null || true

# Qt apps — recolor to the INDEX palette via qt6ct/qt5ct (custom palette, Fusion base)
say "theming Qt apps (qt6ct/qt5ct INDEX palette)..."
for V in qt6ct qt5ct; do
  mkdir -p "$CFG/$V/colors"
  cp -f "$DIR/labwc/config/$V/colors/the-index.conf" "$CFG/$V/colors/the-index.conf" 2>/dev/null || true
  cat > "$CFG/$V/$V.conf" <<QTCONF
[Appearance]
color_scheme_path=$HOME/.config/$V/colors/the-index.conf
custom_palette=true
standard_dialogs=default
style=Fusion

[Fonts]
fixed="Perfect DOS VGA 437 Universal,11,-1,5,50,0,0,0,0,0"
general="Perfect DOS VGA 437 Universal,11,-1,5,50,0,0,0,0,0"

[Interface]
menus_have_icons=true
toolbutton_style=4
QTCONF
done

# Browsers: make Firefox-family + Chromium-family use ONLY the labwc titlebar (no double bar)
say "fixing browser titlebars (Firefox / Chromium families)..."
sh "$DIR/labwc/app-fixes/apply-browser-fixes.sh" 2>/dev/null || true
# default-app picker (wofi menu) -> ~/.local/bin
mkdir -p "$HOME/.local/bin"
cp -f "$DIR/labwc/app-fixes/index-default-apps" "$HOME/.local/bin/index-default-apps" 2>/dev/null || true
cp -f "$DIR/labwc/app-fixes/index-snip" "$HOME/.local/bin/index-snip" 2>/dev/null || true
chmod +x "$HOME/.local/bin/index-snip" 2>/dev/null || true
chmod +x "$HOME/.local/bin/index-default-apps" 2>/dev/null || true
grep -q 'local/bin' "$HOME/.bash_profile" 2>/dev/null || printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bash_profile"
grep -q 'local/bin' "$HOME/.config/fish/config.fish" 2>/dev/null || printf 'fish_add_path "$HOME/.local/bin"\n' >> "$HOME/.config/fish/config.fish"
note "if a browser was open or not yet set up, re-run after launching it once"

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

# ---------- 7c. SILENT BOOT (quiet kernel messages) — UNIVERSAL ----------
# Covers every bootloader: edits whichever cmdline source the system actually
# uses (systemd-boot entries, GRUB, Limine, UKI /etc/kernel/cmdline,
# /etc/cmdline.d). Backs up before touching anything. Also quiets the console.
say "quieting boot messages (silent boot, all bootloaders)..."
QUIET="quiet loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0 udev.log_level=3"
addquiet(){ # $1=file — returns 0 (skip) if already done, else backs up + returns 1
  [ -f "$1" ] || return 0
  grep -q "loglevel=3" "$1" 2>/dev/null && return 0
  sudo cp "$1" "$1.index-bak" 2>/dev/null || true
  return 1
}

# 1) systemd-boot loader entries
if [ -d /boot/loader/entries ]; then
  for e in /boot/loader/entries/*.conf; do addquiet "$e" || sudo sed -i "s/^\(options .*\)$/\1 $QUIET/" "$e" 2>/dev/null || true; done
  note "systemd-boot entries patched"
fi
# 2) GRUB
if [ -f /etc/default/grub ]; then
  if addquiet /etc/default/grub; then :; else
    sudo sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $QUIET\"/" /etc/default/grub 2>/dev/null || true
    command -v grub-mkconfig >/dev/null && sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
  fi
  note "GRUB patched"
fi
# 3) Limine (the one that bit us)
for L in /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /boot/limine.cfg; do
  if [ -f "$L" ]; then
    if addquiet "$L"; then :; else
      sudo sed -i "s/\(cmdline:.*\)$/\1 $QUIET/I; s/\(KERNEL_CMDLINE\[[^]]*\]=.*\)$/\1 $QUIET/I" "$L" 2>/dev/null || true
    fi
    note "Limine patched ($L)"
  fi
done
# 4) UKI / mkinitcpio cmdline sources
if [ -f /etc/kernel/cmdline ]; then
  addquiet /etc/kernel/cmdline || sudo sed -i "s/$/ $QUIET/" /etc/kernel/cmdline 2>/dev/null || true
  command -v mkinitcpio >/dev/null && sudo mkinitcpio -P 2>/dev/null || true
  note "/etc/kernel/cmdline patched (UKI rebuilt)"
fi
if [ -d /etc/cmdline.d ]; then
  echo "$QUIET" | sudo tee /etc/cmdline.d/10-index-quiet.conf >/dev/null 2>&1 || true
  command -v mkinitcpio >/dev/null && sudo mkinitcpio -P 2>/dev/null || true
  note "/etc/cmdline.d patched"
fi
# 5) console quiet regardless of bootloader (kernel printk)
echo "kernel.printk = 3 3 3 3" | sudo tee /etc/sysctl.d/20-index-quiet.conf >/dev/null 2>&1 || true

# standard folders (Pictures, Downloads, Documents...) + default apps
command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update 2>/dev/null || true
mkdir -p "$HOME/Pictures" 2>/dev/null || true
if command -v xdg-mime >/dev/null 2>&1; then
  # sensible defaults for common file types (only if the app is installed)
  setdef() { command -v "$1" >/dev/null 2>&1 && shift && { app="$1"; shift; for m in "$@"; do xdg-mime default "$app" "$m" 2>/dev/null || true; done; } }

  setdef thunar   thunar.desktop        inode/directory
  setdef foot     foot.desktop          text/plain text/x-shellscript application/x-shellscript
  setdef imv      imv.desktop           image/png image/jpeg image/gif image/webp image/bmp image/tiff
  setdef mpv      mpv.desktop           video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo \
                                        audio/mpeg audio/flac audio/ogg audio/wav audio/x-wav
  setdef zathura  org.pwmt.zathura.desktop application/pdf application/epub+zip
  setdef file-roller file-roller.desktop   application/zip application/x-tar application/gzip \
                                           application/x-7z-compressed application/vnd.rar
  unset -f setdef 2>/dev/null || true
fi

# viewers/players for those defaults + a GUI to change them later
if command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm imv mpv zathura zathura-pdf-mupdf file-roller 2>/dev/null || true
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
chk "$CFG/quickshell/Notifications.qml"          "notifications"
chk "$CFG/quickshell/Settings.qml"               "settings panel"
chk "$CFG/quickshell/Calendar.qml"               "calendar + media"
chk "$CFG/foot/foot.ini"                          "Foot terminal config (130x40)"
chk "$CFG/quickshell/lock/lock.qml"              "INDEX lock"
[ -f "$CFG/quickshell/lock/assets/intro.mp4" ] && ok "boot video (intro.mp4)" || note "no boot video (optional)"
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
