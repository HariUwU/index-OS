# WILL OF THE CITY :: THE INDEX

An INDEX look for KDE Plasma 6. KWin keeps managing the windows, so windows
float and can be moved freely. Plasma's own shell is turned off. Quickshell
draws a top bar with a Windows-style taskbar, the wallpaper, the notifications
and the start menu. The INDEX lock screen and splash are included.

## Requirements

- An installed, bootable Arch Linux or Arch-based system (including CachyOS),
  working internet and graphics drivers suitable for a Wayland session
- A normal user with `sudo` (for dependencies and the optional login screen)
- Python 3 for the text selector: `sudo pacman -Syu --needed python`

KDE does not need to be preinstalled when using `setup.sh`. Selecting **Desktop**
installs Plasma 6/KWin and Quickshell before applying INDEX settings, plus Dolphin,
PipeWire audio with PulseAudio compatibility, WirePlumber, fonts and media tools.
Plasma brings System Settings, the KDE polkit password agent and PowerDevil as
dependencies. The network, Bluetooth, audio and display Settings modules are
included too. Other dependencies follow your selected components; review the
exact list with `--dry-run`. Current Arch repositories include `quickshell`.

## Install

For the native Arch package, run `sudo pacman -U ./index-os-0.1.1rc12-1-any.pkg.tar.zst`,
then `index-setup` as your normal user. Pacman installs the selector and its basic
dependencies; the same checklist below applies your chosen components. See
[package instructions](packaging/arch/README.md) for verification and removal.

Start the component selector as your normal user:

```bash
bash setup.sh
```

Choose the desktop, boot login screen, intro video, terminal themes, Fastfetch,
Windows shortcuts, Quick Settings, clipboard history, Prescript widget or cursor
files. Clipboard history includes Windows shortcuts; desktop widgets include the
desktop. Fastfetch and terminal themes can be installed independently. The login
screen is optional because it changes the display manager.

For a fresh system with no desktop or display manager, select **Desktop + Login
screen**, finish setup, then reboot. Login installs and enables the INDEX greetd
display manager and starts Plasma Wayland after authentication. It is not selected
by default. A reproducible console install is:

```bash
bash setup.sh --components desktop,login --dry-run
bash setup.sh --components desktop,login
sudo reboot
```

Add any other components you want to that list, or use the interactive selector.
Media is optional: source users can add files in `assets/` before setup; pacman
users use `~/.local/share/index/assets/`. See [optional media](assets/README.md).
Only intro videos and login background music are omitted. The INDEX logo,
wallpaper, profile image, power icons and sound effects are retained. The author's
modified Universal font remains the system font. Missing optional video/music is skipped.
With **Desktop** alone, choose **Plasma (Wayland)** in your existing display
manager and log in again. Without a display manager, log in as your normal user
at a local text console and run `startplasma-wayland`; repeat this after each boot.
Desktop alone never enables or replaces a display manager. **Login** alone changes
the login screen; select Desktop too to apply the INDEX desktop on a fresh system.

Keep the network service used during base installation running. INDEX installs
NetworkManager tools but does not switch network services. If you choose to use
NetworkManager, configure it and enable `NetworkManager.service`, avoiding a
second network manager on the same interface. For Bluetooth hardware, enable
`bluetooth.service`. These service choices are separate from installing packages.

Use **Up/Down** to move, **Space** to check or uncheck a component, and **Enter**
to review. Press **Enter** on the review screen to install, or **Esc** to cancel.
The selector remembers your previous choices and selects required features
together. The review shows the exact dependencies before applying anything.
Intro video choices are kept; change the video later in **Settings → Intro Video**.
Deselecting intro goes directly to password.

```bash
bash setup.sh --components desktop,intro,fastfetch --dry-run
bash setup.sh --components desktop,intro,fastfetch --manager yay
bash setup.sh --components login,intro --intro-video "$HOME/Videos/intro.mp4"
bash setup.sh --components fastfetch
bash setup.sh --components desktop --no-packages
```

`pacman` is the default dependency installer. `--manager yay` uses your existing
yay installation. The native `index-os` package adds **INDEX Setup** to the app menu
and the `index-setup` command. See [Arch package instructions](packaging/arch/README.md)
to build and install it with pacman. The same checklist works from source and from
the package. Public AUR/repository publication is separate from the local build.

Disabled desktop widgets and shortcut registrations stay off. Existing optional
terminal/Fastfetch themes from an earlier run remain until explicitly restored:

```bash
bash tools/install-extras.sh --components terminals,fastfetch --restore
```

The cursor option builds the slim INDEX Needle theme into your user icons folder
for review. It leaves the current pointer active. See
[`cursor/index-needle/README.md`](cursor/index-needle/README.md) for its preview.

### Change the intro later

Open **Win+A → Settings → Intro Video** (or right-click the volume in the top
bar, then choose **Intro Video**). Choose **Lock Screen** or **Login Screen**,
click **Choose Video**, and select a video. **Preview** plays it in the settings
window; **Use Video** saves it for that screen. The on/off button skips the intro
without losing your chosen video. **Use your assets/intro.mp4** selects the optional
file you supplied before setup; without that file, the intro is skipped.

On the **Login Screen** tab, choose **Once per boot** (the default) or
**Every login**. Once per boot skips the video when returning after logout;
Every login plays whenever the login screen opens. Both modes work with supplied
and custom videos. Changing the video, selecting the assets video, or toggling the
intro preserves frequency. Lock-screen playback frequency is unchanged.

Login-screen changes open a KDE password dialog. Cancelling leaves the saved
choice unchanged. Videos are validated and copied, so moving the original file
afterwards does not break the screen. Changes apply the next time that screen opens,
subject to the selected frequency. Once per boot counts the first greeter launch,
even if playback was disabled, skipped, or failed. Choosing a new video does not
reset it; use **Preview** to watch now.

The command-line controls remain available from this source folder:

```bash
python3 tools/index-intro.py --video "$HOME/Videos/my intro.webm"
python3 tools/index-intro.py --scope user --disable
python3 tools/index-intro.py --scope login --enable
python3 tools/index-intro.py --scope login --frequency boot
python3 tools/index-intro.py --scope login --frequency always
python3 tools/index-intro.py --default
python3 tools/index-intro.py --status
```

`user` changes the lock screen, `login` changes the boot login screen, and the
default `both` changes both. `--frequency` requires explicit `--scope login`;
`user` and `both` are rejected before changes. Older login settings default to
`boot`, including custom videos. Their saved choices are independent. Reinstalling a
screen reapplies its saved choice. Invalid or stalled video falls back to password.

### Direct desktop setup

The lower-level `install-desktop.sh` below expects Plasma and its command-line tools to
be installed already. Use `bash setup.sh` above for installation from bare Arch;
`--no-packages` is only for systems whose selected dependencies are already present.

KDE menus, toolbars, dialogs and window titles use the repaired INDEX pixel
font (Perfect DOS VGA 437 Universal). Already-open apps may need reopening
after installation to pick up the new font.

```bash
bash install-desktop.sh                # install and apply
bash install-desktop.sh --no-packages  # skip pacman
```

Then log out and log in again. The script makes a backup first, and you can
run it twice without problems.

## Restore

```bash
bash install-desktop.sh --restore
```

This brings back the Plasma shell, removes the INDEX service and restores your
old settings from the latest backup in `~/.local/share/index/backups/`.
Log out and in again afterwards.

## VM testing (VirtualBox)

Use an installed Arch VM with a normal sudo-enabled account, working internet
and suitable Wayland graphics support. Select Desktop + Login screen in setup
for a base system, or Desktop when keeping an existing Plasma login manager.
VirtualBox Guest Additions may be installed separately for dynamic resizing and
multiple displays. Disable disk discard on the test VM if the host's VirtualBox
storage path stalls. Keep VM-specific configuration separate from the package.

After logging into INDEX, run `bash tools/verify-desktop.sh` from the source
folder, or `bash /usr/share/index-os/tools/verify-desktop.sh` for the package.
This checks services, fonts, applications, shortcuts and the Fastfetch logo.
Check real audio playback, password unlock and logout/login separately.

## Desktop controls

- Right-click an app in Start to pin or unpin it. Right-click a pinned icon
  for New Window or Unpin. Pins survive a shell restart.
- Win+Tab opens KDE Overview; Alt+Tab keeps its usual window switching.
- Win+A opens Quick Settings; Win+V opens clipboard history.
- Win+Shift+S selects a screenshot region; Ctrl+Shift+Esc opens System Monitor.
- Win+E opens Files, Win+I opens Settings, and Win+D shows the desktop.

Quick Settings includes volume, Night Light and Do Not Disturb. Wireless,
microphone and brightness controls require the corresponding hardware.

Fastfetch uses the cyan INDEX emblem instead of the distribution logo. Its
compact text logo fits the default terminal; `fastfetch/index-full.txt` keeps
the original full-size artwork. Setup backs up any existing fastfetch config.

Run `bash tools/verify-desktop.sh` inside a running INDEX session for focused
application, polkit agent, audio-server, service, shortcut, font and fastfetch
checks. UI interactions and actual audio playback still need a manual review.
Run it after the first graphical login, not from the installation text console.
Package installation is checked separately from the desktop.

## How the bridge works

- KWin has no window list for Quickshell, so `bridge/index-kwin-bridge` (Python)
  loads `kwin-bridge.js` into KWin.
- The KWin script sends window changes over D-Bus (`org.index.KWinBridge`), and
  the bridge prints them as JSON lines for Quickshell.
- Quickshell sends commands back (activate, minimize, close, change desktop)
  and the bridge runs them in KWin. The Meta key opens the start menu the same way.
