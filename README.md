<div align="center">

# WILL OF THE CITY :: THE INDEX

**A cyan CRT desktop for Linux.**
Pixel font, glowing emblem, bracket titlebars, and a cinematic lock screen.

`>_ THE INDEX_`

</div>

---

## What is this?

A complete desktop you can install in one command. It replaces your whole
desktop environment with a terminal-inspired cyan interface — every window gets
`[_] [□] [X]` bracket buttons, apps are recolored to match, and your machine
boots straight into a lock screen with your own intro video.

Built on **labwc** (the window manager) and **quickshell** (the bar, menu, and
lock). Themed after *The House of Spiders: The Index*.

**Best on a fresh install with no desktop environment.** It's designed to be
your desktop, not to sit next to one.

---

## Install

**You need:** an Arch-based system (CachyOS, EndeavourOS, Arch) installed with
**no desktop environment**, and an internet connection.

```bash
# 1. tools
sudo pacman -S --needed git base-devel

# 2. yay (needed for quickshell)
git clone https://aur.archlinux.org/yay.git ~/yay && (cd ~/yay && makepkg -si)

# 3. this
git clone https://github.com/HariUwU/index-OS.git ~/index-OS
cd ~/index-OS
./install.sh

# 4. done
reboot
```

The installer prints a checklist at the end — every line should be a green ✓.
If something shows red, that one piece is missing and the line tells you what.

After reboot your machine goes straight to the INDEX lock screen. Type your
password and you're in. **Safe to re-run `./install.sh` any time.**

<details>
<summary><b>Other distros (Debian, Ubuntu, Fedora, openSUSE)</b></summary>

The installer detects `apt` / `dnf` / `zypper` and installs the right packages.
It works, but it's **experimental** — quickshell isn't packaged outside Arch, so
the installer compiles it from source. That takes several minutes and is the
most likely thing to fail. If it does, the error names the missing piece; see
the [quickshell install docs](https://quickshell.outfoxxed.me/docs/guide/install/).

| Distro | Status |
|--------|--------|
| Arch / CachyOS / EndeavourOS | ✅ tested |
| Debian / Ubuntu | ⚠️ experimental |
| Fedora | ⚠️ experimental |
| openSUSE | ⚠️ experimental |

</details>

---

## Using it

| Key | Does |
|-----|------|
| `Super` + `Return` | Open a terminal |
| `Super` + `D` | App launcher |
| `Super` + `Q` | Close window |
| `Super` + `F` | Maximize |
| `Super` + `L` | Lock the screen |
| `Super` + `1`–`5` | Switch desktop |
| `Alt` + `Tab` | Next window |
| `Print` | Screenshot → `~/Pictures` |
| `Shift` + `Print` | Select area → clipboard |
| Right-click desktop | Menu |

Brightness, volume, and media keys work as normal.

**The bar** (top of screen) has the start menu on the left — click the emblem,
then type to search your apps. On the right: network, bluetooth, battery,
volume (scroll to change, click to mute), tray, and clock.

---

## Make it yours

Everything lives in `assets/`. Drop a file in, re-run `./install.sh`.

| Want to change | Do this |
|----------------|---------|
| Lock screen music | Replace `assets/sounds/bg.mp3` |
| Boot intro video | Add `assets/intro.mp4` |
| Your profile picture | Replace `assets/DefaultProfile.jpg` |
| Wallpaper | Replace `wallpaper/the-index.png` |
| Add a font | Drop any `.ttf` in `assets/` |

**The boot intro** plays once per boot, before the lock screen. Double-click to
show a skip button. No video? It goes straight to the lock. On a VM or software
GPU the installer automatically downscales it so it doesn't stutter.

**Thai text** works out of the box if you add `PerfectDOSVGA437-Thai.ttf` to
`assets/` — Thai characters use the pixel font automatically, and anything
neither font covers falls back to DejaVu Sans.

> Your `intro.mp4` and anything in `assets/boss/` stay on your machine — they're
> ignored by git and never uploaded.

---

## The lock screen

The INDEX lock is the **only** thing guarding your session, and it never locks
on its own — only when you press `Super` + `L` or something asks it to.

It has a few things in it:

- **Scramble + PAM auth** — type your real password
- **WILL OF THE CITY modal** — after repeated failures. Get the fixer password
  wrong here and the machine powers off. That's intentional.
- **CLASH** — click `>_ CLASH TO ENTER _<` for an optional turn-based fight.
  Beat the boss and you're in. Add your own sprites at `assets/boss/boss.png`
  and `assets/boss/player.png`, or it uses the emblem.

> ⚠️ Because login is automatic, the lock is your only password prompt. The
> first time you set this up, check that it unlocks before you rely on it —
> keep `Ctrl` + `Alt` + `F2` handy to reach a terminal if you need to.

---

## If something breaks

**The bar or lock doesn't appear** — run it in a terminal to see the error:

```bash
quickshell -p ~/.config/quickshell/shell.qml
```

**Nothing at all after reboot** — press `Ctrl` + `Alt` + `F2`, log in, and run
`./install.sh` again. The checklist will show what's missing.

**Notifications not showing** — test with `notify-send "THE INDEX" "hello"`.

**Everything is laggy / the video freezes** — you're probably in a VM without
GPU acceleration. This needs a real GPU: bare metal, or QEMU with virtio-gpu.
**VirtualBox will not work** — it can't give a Wayland compositor what it needs.

---

## Good to know

- Some newer GNOME apps (libadwaita) draw their own titlebar and **can't** be
  made to use the cyan one. That's a limitation of those apps, not this setup.
- The pixel font is sharp in the terminal but can look soft at small sizes in
  regular apps.
- Browsers are patched to use the system titlebar. Quit and reopen them once
  after installing.

---

## What's inside

| Path | What it is |
|------|-----------|
| `install.sh` | The installer — does everything |
| `labwc/` | Window manager config + the bracket titlebar theme |
| `quickshell/` | The bar, atmosphere, notifications, and lock screen |
| `assets/` | Fonts, sounds, images — swap these to customize |
| `wallpaper/` | The emblem wallpaper |

---

<div align="center">

Cyan `#5DADE2` · Bright `#85C5E8` · Dim `#3A7CA5` · Red `#FF6B6B` · Background `#05080d`
Font: Perfect DOS VGA 437

*"By the geometry of inevitability, the prey gathers here."*

</div>
