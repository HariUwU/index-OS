#!/usr/bin/env bash
# Read-only checks of the built package payload.
set -euo pipefail
package=${1:?Usage: bash verify-package.sh path/to/index-os.pkg.tar.zst}
entries=$(bsdtar -tf "$package")
while IFS= read -r path; do
    case "$path" in
        usr/|usr/*|.PKGINFO|.BUILDINFO|.MTREE|.INSTALL) ;;
        *) printf 'Unexpected package path: %s\n' "$path" >&2; exit 1 ;;
    esac
done <<< "$entries"
for required in \
    usr/bin/index-setup usr/bin/index-intro usr/share/applications/index-os.desktop \
    usr/share/index-os/setup.sh usr/share/index-os/install-desktop.sh usr/share/index-os/tools/setup.py \
    usr/share/index-os/tools/setup_menu.py usr/share/index-os/tools/index-askpass.sh \
    usr/share/index-os/tools/install-assets.py \
    usr/share/index-os/bridge/index-kwin-bridge usr/share/index-os/quickshell/IntroSettings.qml \
    usr/share/index-os/fastfetch/index.txt usr/share/index-os/greeter/run-greeter \
    usr/share/index-os/kde/aurorae/index/indexrc \
    usr/share/index-os/kde/look-and-feel/org.index.desktop/contents/defaults \
    usr/share/index-os/assets/PerfectDOSVGA437-Universal.ttf \
    usr/share/index-os/assets/Logo.png usr/share/index-os/assets/Power.png \
    usr/share/index-os/assets/Restart.png usr/share/index-os/quickshell/assets/wall.png \
    usr/share/index-os/assets/sounds/check.wav usr/share/index-os/assets/sounds/success.wav \
    usr/share/index-os/assets/sounds/ui/scramble.mp3 \
    usr/share/pixmaps/index-os.png \
    usr/share/licenses/index-os/LICENSE usr/share/licenses/index-os/ATTRIBUTION.md; do
    grep -qxF "$required" <<< "$entries" || { printf 'Missing runtime file: %s\n' "$required" >&2; exit 1; }
done
if grep -Eq '(^|/)(\.ssh|\.git|dist|preview|__pycache__)/|tools/vm-|tools/test-' <<< "$entries"; then
    echo 'Unexpected development or personal files in package' >&2; exit 1
fi
if grep -Ei '\.(mp4|webm|mkv|mov|m4v|avi)$|/bg\.mp3$' <<< "$entries"; then
    echo 'Intro videos and login background music must not be bundled' >&2; exit 1
fi
bsdtar -xOf "$package" .PKGINFO | grep -qx 'pkgname = index-os'
bsdtar -xOf "$package" .PKGINFO | grep -qx 'arch = any'
echo 'PASS: artwork, wallpaper, sound effects and Universal font retained; videos/background music excluded'
