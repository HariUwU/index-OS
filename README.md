# WILL OF THE CITY :: THE INDEX

An INDEX desktop for **KDE Plasma 6 / KWin**, with floating windows, a Windows-style
taskbar, Quickshell panels, native locking and an optional login screen.

![INDEX desktop with its top taskbar, workspaces and Prescript widget](docs/images/index-desktop.png)

Desktop captured in the Arch Linux test VM.

The previous labwc version is preserved on the
[`old` branch](https://github.com/HariUwU/index-OS/tree/old). The current desktop
and installer live on `main`.

## Install with yay

If you already have **yay**, enable the signed INDEX repository once per computer:

```bash
curl -fLO https://github.com/HariUwU/index-OS/releases/download/pacman-repo/enable-index-repo.sh
bash enable-index-repo.sh
```

Then install INDEX and open the component selector:

```bash
yay -Syu index-os
index-setup --manager yay
```

Run yay and INDEX Setup as your normal user; they request sudo when needed.
`--manager yay` also uses yay for the dependencies of your selected components.
After the initial synchronization, `yay -S index-os` works too; use `yay -Syu`
for updates.

INDEX currently comes from our signed repository. An AUR package has not been
published, so the one-time repository setup is required for yay too. See the
[repository setup and signing key](packaging/repo/README.md).

## Install with pacman

After enabling the same repository above, you can use pacman directly:

```bash
sudo pacman -Syu index-os
index-setup
```

After the initial synchronization, `sudo pacman -S index-os` works normally.
Updates are included in `sudo pacman -Syu`.

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

## Optional intro video and login music

The intro video and login background music are supplied by you. Both are optional.
Before setup applies your selected components, put your own files at these exact paths:

| Personal file | Path |
|---|---|
| Intro video | `~/.local/share/index/assets/intro.mp4` |
| Login background music | `~/.local/share/index/assets/sounds/bg.mp3` |

Create the folders first, then copy your files into them using those filenames:

```bash
mkdir -p ~/.local/share/index/assets/sounds
```

If you use `XDG_DATA_HOME`, place them under `$XDG_DATA_HOME/index/assets/`
instead. Source users can also put them in `assets/intro.mp4` and
`assets/sounds/bg.mp3` inside the extracted project.

Run `index-setup` (or `bash install.sh` for source installs). Select **Intro video**
if you want video playback. Setup pauses on **Optional video and music** and shows
the exact paths and whether each file is present. You can add files from another
terminal while this screen is open:

- **R**: recheck files.
- **Enter**: continue to the final install review, with or without either file.
- **Esc**: cancel before installation changes.

On a fresh install without these files, the password screen opens directly and
no login background music plays. Existing installed media and saved custom intro
choices are kept. Change your video later in **Win+A → Settings → Intro Video**.

The INDEX logo, wallpaper, power icons and sound effects are included. INDEX uses
the author's modified `PerfectDOSVGA437-Universal.ttf` as its system font; no
font download or replacement is required. See [all optional file names](assets/README.md).

## Install from source

The repository and RC13 installer archive have a flat layout: desktop files
are at the root. Keep the extracted files together and run `install.sh`.

Clone this repository, or extract the complete
[source installer](https://github.com/HariUwU/index-OS/releases/download/v0.1.1rc13/index-os-0.1.1rc13-installer.tar.gz),
open a terminal in its folder, then install Python and start setup:

```bash
sudo pacman -Syu --needed python
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
drivers, and a normal user allowed to use `sudo`. Pacman package users get Python
automatically; the command above is for source installs.

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
