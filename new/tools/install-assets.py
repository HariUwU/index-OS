#!/usr/bin/env python3
"""Install optional INDEX media from source assets, then the fixed user overlay.

Both source installs and index-setup use this helper. User media belongs in
${XDG_DATA_HOME:-$HOME/.local/share}/index/assets with the names below.
The Universal font always comes from the canonical source assets directory.
Saved intro choices and intro-user.mp4 are owned by index-intro.py.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess


FONT = 'PerfectDOSVGA437-Universal.ttf'
IMAGES = ('Logo.png', 'Power.png', 'Restart.png')
LOCK_SOUNDS = tuple('sounds/' + name for name in (
    'bg.mp3', 'click.wav', 'check.wav', 'fail.wav', 'success.wav'))
UI_SOUNDS = tuple('sounds/ui/' + name for name in (
    'notify.wav', 'tick.wav', 'connect.wav', 'disconnect.wav', 'menu.wav',
    'error.wav', 'scramble.mp3'))
LOCK_MEDIA = (*IMAGES, 'intro.mp4', *LOCK_SOUNDS)
OPTIONAL_MEDIA = (*LOCK_MEDIA, 'wall.png', *UI_SOUNDS)
LOGIN_ASSETS = Path('/usr/share/index-greeter/assets')


def copy_asset(source, destination, privileged=False):
    if privileged:
        # Keep the caller's HOME/XDG selection; elevate only the fixed write.
        subprocess.run(['sudo', 'install', '-D', '-m', '644',
                        str(source), str(destination)], check=True)
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != destination.resolve():
            shutil.copyfile(source, destination)


def install_assets(source, config, data, scope):
    """Copy whitelisted files; absent optional files leave existing files alone."""
    font = source / 'assets' / FONT
    if not font.is_file():
        raise FileNotFoundError(f'Missing canonical INDEX font: {font}')
    if scope not in ('user', 'login'):
        raise ValueError(f'Unknown asset scope: {scope}')

    quickshell = config / 'quickshell/index'
    lnf = data / 'plasma/look-and-feel/org.index.desktop/contents'
    locks = (quickshell / 'lock/assets',
             data / 'plasma/shells/org.index.desktop/contents/lockscreen/assets',
             lnf / 'lockscreen/assets')
    font_targets = (LOGIN_ASSETS,) if scope == 'login' else (
        data / 'fonts/index', *locks)
    count = 0
    for target in font_targets:
        copy_asset(font, target / FONT, scope == 'login')
        count += 1

    # Deliberately no glob/rglob: profile photos, other fonts, custom intros and
    # arbitrary files must never enter the copy plan. Later roots win per file.
    for root in (source / 'assets', data / 'index/assets'):
        for relative in OPTIONAL_MEDIA:
            asset = root / relative
            if not asset.is_file():
                continue
            if scope == 'login':
                if relative not in LOCK_MEDIA:
                    continue
                targets = (LOGIN_ASSETS,)
            elif relative == 'wall.png' or relative in UI_SOUNDS:
                targets = (quickshell / 'assets',)
            else:
                targets = locks
                if relative == 'Logo.png':
                    targets = (*targets, lnf / 'assets')
            for target in targets:
                copy_asset(asset, target / relative, scope == 'login')
                count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=('user', 'login'), default='user',
                        help='user = desktop/lock screens; login = greeter via sudo')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    count = install_assets(source, config, data, args.scope)
    print(f'INDEX {args.scope} assets: {count} file copy/copies (optional media may be absent)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Asset installation failed: {error}')
