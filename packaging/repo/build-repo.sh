#!/usr/bin/env bash
# Build metadata on Arch from an already signed INDEX package.
# Package signing/private keys remain outside the repository.
set -euo pipefail
[[ $# == 2 ]] || { echo 'Usage: bash build-repo.sh package.pkg.tar.zst output-directory' >&2; exit 2; }
package=$(realpath "$1")
output=$(realpath -m "$2")
name=$(basename "$package")
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f $package && -f $package.sig ]] || { echo 'Package and detached .sig are required.' >&2; exit 1; }
[[ $(bsdtar -xOf "$package" .PKGINFO | sed -n 's/^pkgname = //p') == index-os ]] || {
    echo 'Only the index-os package belongs in this repository.' >&2; exit 1;
}
work=$(mktemp -d)
trap 'rm -rf -- "${work:?}"' EXIT
mkdir -m 700 "$work/gnupg"
gpg --homedir "$work/gnupg" --batch --import "$source_dir/index-os-signing-key.asc" >/dev/null 2>&1
actual=$(gpg --homedir "$work/gnupg" --batch --with-colons --list-keys 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }')
expected=$(tr -d '\r\n' <"$source_dir/FINGERPRINT")
[[ $actual == "$expected" ]] || { echo 'Unexpected repository public key.' >&2; exit 1; }
gpg --homedir "$work/gnupg" --batch --verify "$package.sig" "$package"
mkdir -p "$output"
if [[ $package != "$output/$name" ]]; then cp -- "$package" "$package.sig" "$output/"; fi
repo-add --prevent-downgrade "$output/index-os.db.tar.gz" "$output/$name"
# repo-add makes aliases as symlinks; release assets must be regular files.
cp --remove-destination "$output/index-os.db.tar.gz" "$output/index-os.db"
cp --remove-destination "$output/index-os.files.tar.gz" "$output/index-os.files"
cp -- "$source_dir/index-os-signing-key.asc" "$source_dir/FINGERPRINT" \
    "$source_dir/index-os.conf" "$source_dir/enable-index-repo.sh" "$output/"
echo 'Metadata prepared. Sign index-os.db.tar.gz and index-os.files.tar.gz before publication.'
echo 'Copy each detached signature to its .db.sig/.files.sig alias too.'
