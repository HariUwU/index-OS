<div align="center">

```
                           %%%%
                       %+%:     %**-
                   %      .%%%. +     -#:
                   *%#    :%% -%.     %%*
                   %%%%   :%#%:%+   %**#
              %%    %%%   -..+ #%.  %=#%   .%%
           *%-  %%+      +  %   %:-      #%#  +%-
         #%  % %%%      :% .%%%%%*%#:=%   %%%   :%=
        =** % *%%     %%      .-*   :%%%   %%==: +%
        +#. %  %*    +-    %%%%%%%.  %%   %+% -% .%
        -%#  %  %%%-+##  %+**  #%.%  =%-*%%* :%  *%=
         .%+  %%:  %%%%%  %%**%    %#*%%%  -%#  #%%
           =%%   %%%     %#:    +%=    .%%%   %%+
              #%%     %%%%%%%%%%%%%%%%    .%%+
                  %%%%%%.          .%%%%-=
```

```
 ╔══════════════════════════════════════════════════════╗
 ║   W I L L   O F   T H E   C I T Y  ::  T H E  I N D E X   ║
 ╚══════════════════════════════════════════════════════╝
```

`_a cyan CRT desktop for linux._`

![labwc](https://img.shields.io/badge/wm-labwc-5DADE2?style=flat-square&labelColor=05080d)
![quickshell](https://img.shields.io/badge/shell-quickshell-5DADE2?style=flat-square&labelColor=05080d)
![arch](https://img.shields.io/badge/arch-tested-5DE285?style=flat-square&labelColor=05080d)

</div>

```
>_ SEASON :: THE INDEX ................................ district: unregistered
```

## `>_ WHAT_`

A complete desktop, one command. Pixel font, glowing emblem, `[_] [□] [X]`
bracket titlebars on every window, apps recolored to match, and a boot that
goes straight into a cinematic lock screen.

Built on **labwc** (window manager) + **quickshell** (bar, menu, lock).
Themed after *The House of Spiders: The Index*.

> Best on a fresh install with **no desktop environment**. This *is* the desktop.

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ INSTALL_`

**Need:** Arch-based system (CachyOS / EndeavourOS / Arch), **no desktop**, internet.

```bash
# tools
sudo pacman -S --needed git base-devel

# yay (for quickshell)
git clone https://aur.archlinux.org/yay.git ~/yay && (cd ~/yay && makepkg -si)

# the index
git clone https://github.com/HariUwU/index-OS.git ~/index-OS
cd ~/index-OS && ./install.sh

reboot
```

```
:: done.
   ✓ labwc rc.xml            ✓ bracket button [X]
   ✓ labwc autostart         ✓ quickshell shell
   ✓ wallpaper               ✓ INDEX lock
   ✓ titlebar themerc        ✓ tty1 autologin
```

Installer ends with that checklist — all green means good. Red line names what
is missing. **Safe to re-run any time.**

<details>
<summary><code>>_ other distros (debian / fedora / opensuse)_</code></summary>

<br>

Installer detects `apt` / `dnf` / `zypper` and maps package names. Works, but
**experimental** — quickshell is only packaged on Arch, so it gets compiled from
source. Slow, and the most likely thing to fail.

| distro | status |
|--------|--------|
| `arch / cachyos / endeavouros` | ✅ tested |
| `debian / ubuntu` | ⚠ experimental |
| `fedora` | ⚠ experimental |
| `opensuse` | ⚠ experimental |

</details>

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ KEYS_`

```
  Super + Return ....... terminal            Print ............ screenshot
  Super + D ............ launcher            Shift + Print .... region → clip
  Super + Q ............ close               Alt + Tab ........ next window
  Super + F ............ maximize            right-click ...... menu
  Super + L ............ LOCK
  Super + 1..5 ......... desktop
```

Brightness / volume / media keys work as normal.

**The bar** — emblem on the left opens the start menu, type to search apps.
Right side: `NET` · `BT` · `BAT` · `VOL` (scroll to change, click to mute) ·
tray · `_hh:mm AP._`

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ MAKE IT YOURS_`

Drop a file in `assets/`, re-run `./install.sh`.

```
  assets/sounds/bg.mp3 ........... lock screen music
  assets/intro.mp4 ............... boot intro video
  assets/DefaultProfile.jpg ...... your profile picture
  assets/boss/boss.png ........... clash boss sprite
  assets/*.ttf ................... any extra font
  wallpaper/the-index.png ........ wallpaper
```

**Boot intro** plays once per boot, before the lock. Double-click → skip button.
No video → straight to lock. On a VM the installer auto-downscales it so it
doesn't stutter.

**ภาษาไทย** — add `PerfectDOSVGA437-Thai.ttf` to `assets/` and Thai text uses
the pixel font automatically. Anything neither font covers falls back to DejaVu.

> `intro.mp4` and `assets/boss/` stay on your machine — gitignored, never uploaded.

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ THE LOCK_`

```
                    :: AUTHORIZATION REQUIRED ::
```

The only thing guarding your session. It never locks by itself — only
`Super + L`, or when something asks it to.

- **scramble + PAM** — your real password
- **WILL OF THE CITY** — modal after repeated failures. Wrong fixer password
  here powers the machine off. That is on purpose.
- **CLASH** — click `>_ CLASH TO ENTER _<` for an optional turn-based fight.
  Beat the boss, you are in.

> ⚠ Login is automatic, so the lock is your **only** password prompt. First
> setup: confirm it unlocks before relying on it. `Ctrl + Alt + F2` reaches a
> terminal if you need out.

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ WHEN IT BREAKS_`

```bash
# bar or lock missing → see the error
quickshell -p ~/.config/quickshell/shell.qml

# nothing after reboot → Ctrl+Alt+F2, log in, then
cd ~/index-OS && ./install.sh

# notifications
notify-send "THE INDEX" "hello"
```

**Laggy / video freezes** → no GPU acceleration. Needs bare metal or QEMU with
virtio-gpu. **VirtualBox will not work** — it cannot give a Wayland compositor
what it needs.

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ KNOWN LIMITS_`

```
  ✗ libadwaita GNOME apps draw their own titlebar — cannot be overridden
  ~ pixel font is sharp in terminal, soft at small sizes in apps
  ! browsers need one full quit + reopen after installing
```

```
────────────────────────────────────────────────────────────────────────────
```

## `>_ INSIDE_`

```
  install.sh ......... does everything
  labwc/ ............. window manager + bracket titlebar theme
  quickshell/ ........ bar, atmosphere, notifications, lock
  assets/ ............ fonts, sounds, images — swap to customize
  wallpaper/ ......... the emblem
```

```
────────────────────────────────────────────────────────────────────────────
```

<div align="center">

```
  #5DADE2      #85C5E8      #3A7CA5      #FF6B6B      #5DE285      #05080d
   cyan         bright        dim          warn        success        bg
```

`Perfect DOS VGA 437`

*"By the geometry of inevitability, the prey gathers here."*

```
>_ THE INDEX_
```

</div>
