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

# WILL OF THE CITY :: THE INDEX

**A cyan CRT desktop for Linux.**

![labwc](https://img.shields.io/badge/wm-labwc-5DADE2?style=flat-square&labelColor=05080d)
![quickshell](https://img.shields.io/badge/shell-quickshell-5DADE2?style=flat-square&labelColor=05080d)
![arch](https://img.shields.io/badge/arch-tested-5DE285?style=flat-square&labelColor=05080d)

</div>

---

## What is this

A complete desktop environment, themed after *The House of Spiders: The Index*.

Pixel font, glowing emblem wallpaper, `[_] [□] [X]` bracket titlebars on every
window, apps recolored cyan to match, and a boot that goes straight into a
cinematic lock screen with your own intro video.

Built on **labwc** (window manager) and **quickshell** (bar, menu, lock screen).

> Install it on a fresh system with **no desktop environment** — this *is* the
> desktop. It will replace what you have.

---

## Install

You need an Arch-based system (CachyOS, EndeavourOS, Arch) with no desktop
environment installed.

```bash
sudo pacman -S --needed git base-devel

git clone https://aur.archlinux.org/yay.git ~/yay && (cd ~/yay && makepkg -si)

git clone https://github.com/HariUwU/index-OS.git ~/index-OS
cd ~/index-OS && ./install.sh

reboot
```

That's it. The installer handles everything and prints a checklist when it's
done — every line should be green. Reboot and your machine goes straight to the
INDEX lock screen.

Safe to re-run `./install.sh` any time.

<details>
<summary>Other distros (Debian, Ubuntu, Fedora, openSUSE)</summary>

<br>

The installer detects `apt` / `dnf` / `zypper` and installs the right packages,
but this is **experimental** — quickshell is only packaged on Arch, so it gets
compiled from source. That's slow and the most likely thing to fail.

</details>

---

<div align="center">

*"By the geometry of inevitability, the prey gathers here."*

</div>
