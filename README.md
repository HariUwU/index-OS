# WILL OF THE CITY :: THE INDEX

An INDEX desktop for **KDE Plasma 6 / KWin**, with floating windows, a Windows-style
taskbar, Quickshell panels, native locking and an optional login screen.

![INDEX desktop](wallpaper/the-index.png)

The previous labwc version is preserved on the
[`old` branch](https://github.com/HariUwU/index-OS/tree/old). The current desktop
and installer live on `main`.

## Install with pacman

Enable the signed INDEX repository once, then install and open the selector:

```bash
curl -fLO https://github.com/HariUwU/index-OS/releases/download/pacman-repo/enable-index-repo.sh
bash enable-index-repo.sh
sudo pacman -Syu index-os
index-setup
```

After setup, `sudo pacman -S index-os` works normally. Updates are included in
`sudo pacman -Syu`. See the [repository setup and signing key](packaging/repo/README.md).

Run `index-setup` as your normal user, or launch **INDEX Setup** from the app
menu. Pacman installs the setup command and its basic dependencies; the selector
installs the dependencies for the components you choose. On bare Arch, select
**Desktop + Login screen**. Up/Down moves, Space selects and Enter confirms.
Pacman installs Python automatically, so the manual Python prerequisite below applies
only to the extracted source installer. See the
[pacman instructions](packaging/arch/README.md) for updates and removal.

For manual local installation, download the [RC13 pacman package](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc13/index-os-0.1.1rc13-1-any.pkg.tar.zst)
and its [checksum](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc13/index-os-0.1.1rc13-1-any.pkg.tar.zst.sha256),
then run `sudo pacman -U ./index-os-0.1.1rc13-1-any.pkg.tar.zst` and `index-setup`.

The INDEX logo, wallpaper, power icons and sound effects are included.
Only the intro video and login background music are not bundled. To add your own,
put `intro.mp4` and/or `sounds/bg.mp3` in `~/.local/share/index/assets/` before
running `index-setup`, or pause on its **Optional video and music** screen to add
them. Setup shows the exact paths and whether each file is present. Press **R**
to recheck, **Enter** to continue (both files are optional), or **Esc** to cancel.
For source installation, you can also use `assets/` in the extracted project.
See [optional file names](assets/README.md). INDEX keeps the author's modified
Universal font as its system font; no font download or replacement is required.

## Install from source

The repository and RC13 installer archive have a flat layout: desktop files
are at the root. Keep the extracted files together and run `install.sh`.

Clone this repository, or extract the complete
[source installer](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc13/index-os-0.1.1rc13-installer.tar.gz),
open a terminal in its folder, then run:

```bash
bash install.sh
```

Run as your normal user. Setup asks for sudo when installing dependencies or
applying the optional login screen. Keep the complete checkout together: `install.sh`, `setup.sh`, `tools/`,
`assets/` and the desktop folders belong at the repository root.

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
See [desktop instructions](DESKTOP.md) for settings and restoration.

This is a release candidate tested in an Arch VirtualBox VM.
Personal videos/background music, historical sources and local test/build output are excluded
from the publication tree. Font/source credits remain in
[ATTRIBUTION.md](ATTRIBUTION.md).
