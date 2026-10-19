# WILL OF THE CITY :: THE INDEX

An INDEX desktop for **KDE Plasma 6 / KWin**, with floating windows, a Windows-style
taskbar, Quickshell panels, native locking and an optional login screen.

![INDEX desktop](new/wallpaper/the-index.png)

The previous labwc version is preserved on the
[`old` branch](https://github.com/HariUwU/index-OS/tree/old). The current desktop
and installer live on `main`.

## Install with pacman

Download the [RC12 pacman package](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc12/index-os-0.1.1rc12-1-any.pkg.tar.zst)
and its [SHA256 checksum](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc12/index-os-0.1.1rc12-1-any.pkg.tar.zst.sha256).

Install the native Arch package with pacman, then open the component selector:

```bash
sudo pacman -U ./index-os-0.1.1rc12-1-any.pkg.tar.zst
index-setup
```

Run `index-setup` as your normal user, or launch **INDEX Setup** from the app
menu. Pacman installs the setup command and its basic dependencies; the selector
installs the dependencies for the components you choose. On bare Arch, select
**Desktop + Login screen**. Up/Down moves, Space selects and Enter confirms.
Pacman installs Python automatically, so the manual Python prerequisite below applies
only to the extracted source installer. See the
[pacman instructions](new/packaging/arch/README.md) for updates and removal.

The tested package is a local installation file. `pacman -S index-os` requires
an INDEX package repository; it is not published yet.

The INDEX logo, wallpaper, power icons and sound effects are included.
Only the intro video and login background music are not bundled. To add your own,
put `intro.mp4` and/or `sounds/bg.mp3` in `~/.local/share/index/assets/` before
running `index-setup`. For source installation, use `new/assets/` instead.
See [optional file names](new/assets/README.md). INDEX keeps the author's modified
Universal font as its system font; no font download or replacement is required.

## Install from source

Clone this repository, or extract the complete
[source installer](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc12/index-os-0.1.1rc12-installer.tar.gz),
open a terminal in its folder, then run:

```bash
bash install.sh
```

Run as your normal user. Setup asks for sudo when installing dependencies or
applying the optional login screen. Keep `install.sh` beside the included `new/`
folder; the folder contains the desktop, themes and optional-file instructions.

Use **Up/Down** to move, **Space** to select features, and **Enter** to review and
confirm. **Esc** cancels. Choose the desktop, login screen, intro, Fastfetch and
other features independently; required components are selected together.

Works from an installed Arch Linux text console or an existing Arch-based KDE
Plasma 6 system. Start with a bootable system, working internet, suitable graphics
drivers, and a normal user allowed to use `sudo`. Install Python 3 first:

```bash
sudo pacman -Syu --needed python
```

On a fresh system, select **Desktop + Login screen** and reboot after setup.
Setup installs Plasma/KWin, the INDEX shell and their runtime dependencies before
applying settings; KDE does not need to be preinstalled. Login screen installs and
enables the INDEX display manager for graphical login at boot. It is optional
and is not selected by default.

With **Desktop** alone, use your existing display manager's **Plasma (Wayland)**
session. If there is no display manager, log in at a local text console and run
`startplasma-wayland` each time. Setup does not silently enable a display manager.

Dependencies use pacman by default, or your existing yay installation:

```bash
bash install.sh --manager yay
bash install.sh --components desktop,login --dry-run
bash install.sh --components desktop,intro,fastfetch --dry-run
```

Change videos later in **Win+A → Settings → Intro Video**.
See [desktop instructions](new/README.md) for settings and restoration.

This is a release candidate tested in an Arch VirtualBox VM.
Personal videos/background music, historical sources and local test/build output are excluded
from the publication tree. Font/source credits remain in
[ATTRIBUTION.md](new/ATTRIBUTION.md).
