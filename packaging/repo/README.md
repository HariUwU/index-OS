# Signed INDEX pacman repository

The public repository is hosted at:

```text
https://github.com/HariUwU/index-OS/releases/download/pacman-repo
```

## One-time setup

Run these as your normal user on installed Arch-based Linux:

```bash
curl -fLO https://github.com/HariUwU/index-OS/releases/download/pacman-repo/enable-index-repo.sh
bash enable-index-repo.sh
sudo pacman -Syu index-os
index-setup
```

Review `enable-index-repo.sh` before running it if desired. It checks the public
key fingerprint and signed database before requesting sudo. Then it imports and
locally signs the repository key, installs `/etc/pacman.d/index-os.conf`, and adds
one Include line to `/etc/pacman.conf`. Existing official repositories stay enabled.
The original pacman configuration is backed up as `/etc/pacman.conf.before-index-os`.
Re-running the script does not duplicate the Include or overwrite a different
INDEX configuration.

After the initial synchronization, install with `sudo pacman -S index-os` and
update normally with `sudo pacman -Syu`. Rerun `index-setup` after an INDEX update
to apply updated files to your selected desktop components. The package manager
installs the package; INDEX Setup applies the desktop/login configuration.

The repository configuration is:

```ini
[index-os]
SigLevel = Required
Server = https://github.com/HariUwU/index-OS/releases/download/pacman-repo
```

This requires trusted signatures for packages and database metadata, using
[pacman's repository signature settings](https://man.archlinux.org/man/pacman.conf.5.en).

Public signing fingerprint:

```text
679F10777420C93CE7AFBDA8744DA6D2B2A7A225
```

The public key is included here as `index-os-signing-key.asc`; the private key
is never committed or uploaded. This custom repository provides `pacman -S`;
it is separate from Arch's official repositories and an AUR submission.

## Manual key setup

If configuring manually, download `index-os-signing-key.asc` from this directory
or the repository release and compare its fingerprint with the value above.
Then use `sudo pacman-key --init`, `sudo pacman-key --add index-os-signing-key.asc`
and `sudo pacman-key --lsign-key 679F10777420C93CE7AFBDA8744DA6D2B2A7A225`.
Add the repository stanza above to `/etc/pacman.conf`, then run
`sudo pacman -Syu index-os`. See [pacman-key](https://man.archlinux.org/man/pacman-key.8.en).

## Maintainer updates

1. Build and test the new pacman package. Keep intro videos and `sounds/bg.mp3`
   excluded; keep the INDEX artwork, wallpaper, effects and modified Universal font.
2. Sign the package with the existing repository signing key, producing a detached
   `package.pkg.tar.zst.sig` alongside the package.
3. On Arch, run `bash packaging/repo/build-repo.sh /path/to/package.pkg.tar.zst /path/to/publish`.
   The helper verifies the package's signature before creating database metadata.
4. Sign `index-os.db.tar.gz` and `index-os.files.tar.gz` with the same key.
   Copy those signatures to `index-os.db.sig` and `index-os.files.sig` respectively;
   each alias has identical data to its `.tar.gz` file. Verify each signature.
5. Upload the new package and signature to the permanent `pacman-repo` release
   first, then update the database/files assets and their signatures. Retain older
   package files so clients with cached metadata can still download them. Verify
   all public asset digests and a real pacman synchronization after publication.

`repo-add` embeds a package's adjacent signature in its metadata; see the
[repo-add manual](https://man.archlinux.org/man/repo-add.8.en).
Keep signing material and its passphrase backed up outside the project. The
initial key was created with a two-year expiry; renew it before expiry and
republish its public key. Users can rerun setup to import the renewed key;
a different fingerprint requires an explicit trust update.

## Removal

Restore any INDEX components you want to undo with `index-setup --restore-login`
and `index-setup --restore`, then remove the package with `sudo pacman -R index-os`.
To disable the repository, remove its managed Include line from `/etc/pacman.conf`
and `/etc/pacman.d/index-os.conf`. The setup script leaves its original configuration
backup for review. Do not blindly restore that backup after later unrelated pacman
configuration changes.
