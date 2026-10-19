# AUR package

The `index-os` recipe is ready, but has not been uploaded to the AUR. Account
registration is currently unavailable to the maintainer. Use the signed
[pacman repository](../repo/README.md) until it is published.

The [1.0 release](https://github.com/HariUwU/index-OS/releases/tag/v1.0.0) includes
`index-os-1.0.0-aur.tar.gz`, containing `PKGBUILD`, `.SRCINFO`, `index-os.install`
and the recipe's license. It downloads the checksummed source installer from
that release. Installing the package adds INDEX Setup; applying desktop and
login settings is a separate, user-run step.

## Upload when account access is available

Add your publishing SSH public key in the AUR account settings, then clone:

```bash
git clone ssh://aur@aur.archlinux.org/index-os.git
```

Copy the prepared recipe files into that checkout. On Arch, check and publish:

```bash
makepkg --verifysource
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO index-os.install LICENSE
git commit -m 'Initial release: index-os 1.0.0'
git push origin master
```

Check for existing package history before pushing. The AUR accepts the `master`
branch. See the [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines).
Update the root README with direct AUR installation commands only after the
upload is verified.
