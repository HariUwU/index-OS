# Arch package

`index-os` installs the reviewed runtime sources and an **INDEX Setup** launcher.
Run `index-setup` as a normal user to apply your chosen components. The checklist
installs only the dependencies needed for your selection using pacman or yay.

## Install the package

For `sudo pacman -S index-os`, first enable the
[signed INDEX repository](../repo/README.md). Its one-time setup imports the
signing key and configures pacman; `sudo pacman -Syu index-os` then installs
and updates from the repository. Run `index-setup` as your normal user afterward.

For local installation without configuring the repository:

Download the provided `index-os-0.1.1rc12-1-any.pkg.tar.zst` file and open a
terminal in its folder. Keep the package compressed; pacman reads it directly:

```sh
sudo pacman -U ./index-os-0.1.1rc12-1-any.pkg.tar.zst
index-setup
```

Run `index-setup` without sudo. Use Up/Down to move, Space to select and Enter to
review and confirm. On an installed Arch system without a desktop, choose
**Desktop + Login screen**; KDE does not need to be installed first. Setup asks
for sudo when applying the selected components. For an existing Plasma system,
Login is optional. Log out/in after desktop setup; reboot after login setup.

You can also open **INDEX Setup** from the app menu. The package depends on
Python, Bash and sudo, which pacman resolves automatically. `base-devel` is
needed only to build the package, not to install the finished file. Graphics
drivers, working internet and a normal account with sudo remain prerequisites.

When a matching `.sha256` file is supplied, verify the download before installing:

```sh
sha256sum -c index-os-0.1.1rc12-1-any.pkg.tar.zst.sha256
```

RC12 package installation, settings preservation and packaged desktop setup
were checked in the Arch VM. Earlier package lifecycle checks also covered
removal/reinstallation and isolated Fastfetch setup.

## Optional personal files

The INDEX logo, wallpaper, profile image, power icons and sound effects are
included. Only intro videos and login background music are not bundled. Add
`intro.mp4` and/or `sounds/bg.mp3` under `~/.local/share/index/assets/` before
running `index-setup`; source users can add them under `assets/` before setup.
See [`assets/README.md`](../../assets/README.md). The author's modified Universal
font remains the system font. Package generation excludes only video files and
`bg.mp3`, keeping the other original assets.

## Prepare and build

From the repository root, on Windows or Linux:

```sh
python3 packaging/arch/prepare.py --version 0.1.1rc12 --output dist/arch
```

This creates `dist/arch/PKGBUILD`, a runtime source archive with a real SHA-256
checksum, and the package instructions. Preview images, VM access tools, test
output, build directories and unrelated files are excluded.

Build on Arch as a normal user with `base-devel` available:

```sh
cd dist/arch
makepkg
sudo pacman -U ./index-os-0.1.1rc12-1-any.pkg.tar.zst
index-setup
```

You can also launch **INDEX Setup** from the desktop app menu. Package installation
places files under `/usr`; user configuration changes happen through the checklist.
Choose **Login Screen** there to set up greetd, and **Intro Video** to enable the
saved intro. Custom videos are chosen in **Win+A → Settings → Intro Video**.

## Updates and removal

After a package update, rerun `index-setup` to apply the new files to your account.
The existing installer keeps your original backups and saved intro choices.

Before removing the package, restore the components you enabled:

```sh
index-setup --restore-login  # only if you enabled the INDEX boot login
index-setup --restore       # restore Plasma and your saved desktop settings
sudo pacman -R index-os
```

Log out/in after restoring the desktop; reboot after restoring the boot login.

## Repository publication

The signed custom pacman repository is hosted in the `pacman-repo` GitHub release.
See [repository maintenance](../repo/README.md) for signing and metadata updates.
The generated recipe still supports local `makepkg` builds. No AUR submission
has been made; it is separate from the configured binary repository.

The source archive retains `LICENSE` and `ATTRIBUTION.md`, including the separate
terms for bundled third-party fonts. Review those terms before public redistribution.

Reference: [PKGBUILD manual](https://man.archlinux.org/man/PKGBUILD.5.en.html).
