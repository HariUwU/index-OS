# WILL OF THE CITY :: THE INDEX

A Project-Moon-themed **labwc** desktop — cyan CRT terminal aesthetic, pixel
font, glowing emblem, real `[_] [□] [X]` bracket titlebars, and a cinematic
boot lock. One installer, plug & play.

![the index](preview/will-of-the-city-full.html)

---

## Install

```bash
# 1. get git, clone
sudo pacman -S --needed git          # (apt/dnf/zypper on other distros)
git clone https://github.com/HariUwU/index-OS.git ~/index-OS
cd ~/index-OS

# 2. (Arch only) an AUR helper for quickshell
sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/yay.git ~/yay && (cd ~/yay && makepkg -si)

# 3. run it
./install.sh
```

`install.sh` installs everything, lays down the theme + config, sets the
wallpaper, wires the lock, themes apps, makes labwc **auto-start on boot
(silent, autologin)**, and ends with a per-file checklist. Safe to re-run.

Then reboot, or:

```bash
dbus-run-session labwc
```

---

## Distro support

| Distro | Status |
|--------|--------|
| **Arch / CachyOS / EndeavourOS** | ✅ tested — full support (pacman + AUR) |
| **Debian / Ubuntu** (apt) | ⚠️ experimental — quickshell built from source |
| **Fedora** (dnf) | ⚠️ experimental — quickshell built from source |
| **openSUSE** (zypper) | ⚠️ experimental — quickshell built from source |

> quickshell is only packaged on Arch (AUR). On other distros the installer
> compiles it from source — slow, and the most likely thing to fail. If a
> non-Arch install errors, the line it printed tells you which package or
> build step; see https://quickshell.outfoxxed.me/docs/guide/install/

---

## Keys

| Key | Action |
|-----|--------|
| `Super + Return` | terminal (foot) |
| `Super + D` | launcher (wofi) |
| `Super + Q` | close window |
| `Super + F` | toggle maximize |
| `Super + L` | **INDEX lock** (default + only locker) |
| `Super + 1…5` | switch desktop |
| `Alt + Tab` | next window |
| right-click | root menu |

---

## What you get

- **Bracket titlebars** — real `[_] [□] [X]` cyan pixel-glyph buttons (labwc theme).
  Forced server-side so apps use one bar; browsers (Firefox/Chromium family)
  patched to drop their own. *libadwaita GNOME apps can't be forced — Linux limit.*
- **The bar** — emblem/start menu (searchable), workspace pills, clock, system
  tray, volume control (scroll/click-mute).
- **The atmosphere** — drifting cyan motes, subtitle ticker, SEASON/district HUD.
- **The lock** — cinematic boot intro (your own `assets/intro.mp4`, once per boot,
  skippable), scramble + audio + PAM auth, WILL OF THE CITY fixer modal. Default
  + only locker; **no idle auto-lock**.
- **App theming** — INDEX-cyan GTK theme + qt6ct Qt palette + pixel font + foot
  CRT theme, so apps read like the desktop.
- **Silent boot** — autologin + quiet kernel params (all bootloaders) →
  straight into the lock, no text, no desktop flash.

---

## Layout

| Path | What |
|------|------|
| `install.sh` | the one installer (multi-distro, plug & play) |
| `labwc/theme/the-index/` | titlebar theme — the `[_] [□] [X]` bracket buttons |
| `labwc/theme/the-index-gtk/` | INDEX-cyan GTK theme |
| `labwc/config/` | `rc.xml`, `menu.xml`, `autostart`, `environment`, `foot.ini`, qt6ct/qt5ct, gtk, fontconfig |
| `labwc/config/index-lock` | boot-safe lock launcher |
| `labwc/app-fixes/` | browser one-bar fixes (Firefox/Chromium families) |
| `quickshell/shell.qml` | loads bar + atmosphere |
| `quickshell/Bar.qml` | the top bar |
| `quickshell/Atmosphere.qml` | particles + subtitle + HUD |
| `quickshell/lock/lock.qml` | the INDEX lock + boot intro |
| `assets/` | font, Logo, profile, icons, sounds (single source of truth) |
| `wallpaper/` | the glowing-emblem wallpaper |
| `preview/` | target look (browser mockup) |

---

## Customizing

**Lock background song** → replace `assets/sounds/bg.mp3`, re-run `./install.sh`.

**Boot intro video** → drop `assets/intro.mp4` (your own file; gitignored, never
shipped). Plays once per boot, skippable. On a software/virtio GPU the installer
auto-downscales it to 720p30 so it doesn't freeze.

**Lock assets** all live in `assets/` (single source) — the installer copies them
into the lock. Don't edit `quickshell/lock/assets/` directly; it's generated.

---

## The lock

`Super + L` runs the INDEX lock directly; `swayidle` routes any system lock
request to it too. **No idle auto-lock** — the screen only locks when asked.
Wrong fixer password in the WILL OF THE CITY modal powers off (Project Moon
"Fixer" behavior).

> The lock is the only auth gate (autologin has no TTY password). On first setup,
> verify it unlocks before relying on it — keep a TTY (Ctrl+Alt+F2) handy.

---

## Notes / limits

- Needs a real GPU path (bare metal or **QEMU/virtio-gpu**), **not** VirtualBox.
- bar / atmosphere / lock are quickshell QML — if one doesn't render, run it in
  the foreground to see the error: `quickshell -p ~/.config/quickshell/shell.qml`
- Pixel font on small UI text can blur; missing glyphs (CJK/symbols) fall back to
  DejaVu Sans.

---

## Aesthetic

Palette: cyan `#5DADE2` / bright `#85C5E8` / dim `#3A7CA5` / red `#FF6B6B` /
success `#5DE285` / bg `#05080d`. Font: Perfect DOS VGA 437.
From *The House of Spiders: The Index*.

`>_ THE INDEX_`
