# WILL OF THE CITY :: THE INDEX

A Project-Moon-themed **labwc** desktop — cyan CRT terminal aesthetic, pixel
font, glowing emblem, and real `[_] [#] [X]` bracket titlebars.

Built for a fresh, no-desktop Arch / CachyOS base. One installer, plug & play.

## Install

```bash
sudo pacman -S --needed git
git clone https://github.com/HariUwU/index-OS.git ~/index-OS
cd ~/index-OS
./install.sh
```

`install.sh` installs deps (labwc, quickshell, swaybg, swayidle, foot, wofi,
font), lays down the theme + config, sets the wallpaper, wires the lock, and
makes labwc **auto-start on tty1 login**. It ends with a per-file checklist so
you can see everything landed. Safe to re-run.

> quickshell comes from the AUR. If the checklist flags it, install an AUR
> helper and run `yay -S quickshell-git`, then re-run `./install.sh`.

Start it (or just reboot):

```bash
dbus-run-session labwc
```

## Keys

| Key | Action |
|-----|--------|
| `Super+Return` | terminal (foot) |
| `Super+D` | launcher (wofi) |
| `Super+Q` | close window |
| `Super+L` | **INDEX lock** (the default + only locker) |
| `Super+1..5` | desktops |
| right-click | root menu |

## What's in here

| Path | What |
|------|------|
| `install.sh` | the one installer (labwc, plug & play) |
| `labwc/theme/the-index/` | titlebar theme — the `[_] [#] [X]` bracket buttons (PNG glyphs) |
| `labwc/config/` | `rc.xml`, `menu.xml`, `autostart`, `environment` |
| `quickshell/shell.qml` | loads the bar + atmosphere |
| `quickshell/Bar.qml` | top bar — emblem/start menu, workspaces, clock, tray |
| `quickshell/Atmosphere.qml` | particles + subtitle + corner HUD (background layer) |
| `quickshell/lock/lock.qml` | the INDEX lock — scramble, audio, PAM auth |
| `wallpaper/` | the glowing-emblem wallpaper |
| `preview/` | the target look (browser mockup) |

## Swapping the lock song / assets

All lock assets live in ONE place: `assets/` (font, `Logo.png`, `DefaultProfile.jpg`,
`Power.png`, `Restart.png`, `sounds/`). To change the lock background song, replace
`assets/sounds/bg.mp3`, then re-run `./install.sh`. The installer copies `assets/`
into the lock at install time, so the swap takes effect. Don't edit
`quickshell/lock/assets/` directly — it's generated.

## The lock

The **INDEX lock** (`quickshell/lock/lock.qml`) is the default and only locker.
`Super+L` runs it directly, and `swayidle` routes any system lock request
(`loginctl lock-session`) to it too. There is **no idle auto-lock** — the screen
only locks when you ask it to.

## Status / honest notes

- ✅ **Bracket titlebars** — real, themed by labwc from PNG button glyphs.
- ✅ Wallpaper (swaybg), font, palette, lock wiring, auto-start on login.
- ⚠️ **bar / atmosphere / lock** are quickshell QML — if one doesn't render,
  run it in the foreground to see the error and fix from there:
  ```bash
  quickshell -p ~/.config/quickshell/shell.qml
  ```
- The bar's workspace pills switch via `wtype` (labwc has no workspace IPC).
- Needs a real GPU path (bare metal or QEMU/virtio-gpu), **not** VirtualBox.

## Aesthetic

Palette: cyan `#5DADE2` / bright `#85C5E8` / dim `#3A7CA5` / red `#FF6B6B` /
bg `#05080d`. Font: Perfect DOS VGA 437. From *The House of Spiders: The Index*.
