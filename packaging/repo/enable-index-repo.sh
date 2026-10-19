#!/usr/bin/env bash
# Configure the signed INDEX repository; run as your normal sudo-enabled user.
set -euo pipefail
server='https://github.com/HariUwU/index-OS/releases/download/pacman-repo'
fingerprint='679F10777420C93CE7AFBDA8744DA6D2B2A7A225'
config=/etc/pacman.d/index-os.conf
include='Include = /etc/pacman.d/index-os.conf'
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $(id -u) != 0 ]] || die 'Run bash enable-index-repo.sh as your normal user; it requests sudo.'
for tool in curl gpg pacman-key pacman-conf sudo; do
    command -v "$tool" >/dev/null || die "Missing required tool: $tool"
done
work=$(mktemp -d)
trap 'rm -rf -- "${work:?}"' EXIT
mkdir -m 700 "$work/gnupg"
curl --fail --silent --show-error --location --proto '=https' \
    "$server/index-os-signing-key.asc" -o "$work/key.asc"
gpg --homedir "$work/gnupg" --batch --import "$work/key.asc" >"$work/import.log" 2>&1 || {
    cat "$work/import.log" >&2; die 'Could not read the repository key.';
}
actual=$(gpg --homedir "$work/gnupg" --batch --with-colons --list-keys 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }')
[[ $actual == "$fingerprint" ]] || die 'Repository signing-key fingerprint does not match.'
curl --fail --silent --show-error --location --proto '=https' "$server/index-os.db" -o "$work/index-os.db"
curl --fail --silent --show-error --location --proto '=https' "$server/index-os.db.sig" -o "$work/index-os.db.sig"
gpg --homedir "$work/gnupg" --batch --verify "$work/index-os.db.sig" "$work/index-os.db" \
    >"$work/verify.log" 2>&1 || { cat "$work/verify.log" >&2; die 'Repository database signature is invalid.'; }
printf '[index-os]\nSigLevel = Required\nServer = %s\n' "$server" >"$work/index-os.conf"
if grep -qxF "$include" /etc/pacman.conf; then
    [[ -f $config ]] && cmp -s "$work/index-os.conf" "$config" ||
        die 'Existing INDEX configuration differs; review /etc/pacman.d/index-os.conf manually.'
else
    if pacman-conf --repo index-os Server >/dev/null 2>&1; then
        die 'An INDEX repository is already configured elsewhere; review it before continuing.'
    fi
    [[ ! -e $config ]] || cmp -s "$work/index-os.conf" "$config" ||
        die 'A different /etc/pacman.d/index-os.conf already exists.'
fi
printf 'Verified INDEX signing key: %s\n' "$fingerprint"
sudo -v
sudo pacman-key --init
sudo pacman-key --add "$work/key.asc"
sudo pacman-key --lsign-key "$fingerprint"
sudo install -m 644 "$work/index-os.conf" "$config"
if ! grep -qxF "$include" /etc/pacman.conf; then
    if [[ ! -e /etc/pacman.conf.before-index-os ]]; then
        sudo cp -p /etc/pacman.conf /etc/pacman.conf.before-index-os
    fi
    printf '\n# INDEX package repository\n%s\n' "$include" | sudo tee -a /etc/pacman.conf >/dev/null
fi
echo 'INDEX repository enabled with required package and database signatures.'
echo 'Install with: sudo pacman -Syu index-os'
echo 'Then run as your normal user: index-setup'
