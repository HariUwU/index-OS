#!/usr/bin/env python3
"""Choose the parts of THE INDEX to install on Arch-based Linux."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

SRC = Path(__file__).resolve().parent.parent
COMPONENTS = {
    'desktop': 'Desktop: floating windows, top taskbar, wallpaper and KDE theme',
    'login': 'Login screen: INDEX login at boot (uses sudo; changes the display manager)',
    'intro': 'Intro video: use your own video before the password (optional)',
    'terminals': 'Terminal themes: Konsole and Alacritty',
    'fastfetch': 'Fastfetch: cyan INDEX logo and system information',
    'shortcuts': 'Windows shortcuts: Task View, screenshot and task manager',
    'quicksettings': 'Quick Settings: volume, Night Light and Do Not Disturb',
    'clipboard': 'Clipboard history: Win+V (includes Windows shortcuts)',
    'prescript': 'Prescript of the Day widget',
    'cursor': 'Cursor theme (preview): slim INDEX arrow files; keeps your current pointer active',
}
DEFAULT = ['desktop', 'intro', 'terminals', 'fastfetch', 'shortcuts', 'quicksettings', 'clipboard', 'prescript']
PACKAGES = {
    # plasma-desktop pulls in systemsettings, polkit-kde-agent and powerdevil.
    # Its optional KCMs are used by INDEX Settings even without Quick Settings.
    'desktop': ['plasma-desktop', 'plasma-workspace', 'kwin', 'kconfig', 'qt6-tools',
                'breeze', 'breeze-icons', 'quickshell', 'python-dbus', 'python-gobject',
                'qt6-multimedia', 'qt6-5compat', 'playerctl', 'wireplumber', 'pipewire-pulse',
                'dolphin', 'kscreen', 'plasma-nm', 'plasma-pa', 'bluedevil',
                'networkmanager', 'bluez-utils', 'fontconfig', 'ttf-dejavu', 'ffmpeg', 'kdialog'],
    'login': ['greetd', 'cage', 'quickshell', 'qt6-multimedia', 'plasma-workspace', 'kwin', 'breeze-icons'],
    'intro': ['ffmpeg'],
    'terminals': ['konsole', 'alacritty', 'fontconfig', 'kconfig'],
    'fastfetch': ['fastfetch'],
    'shortcuts': ['spectacle', 'plasma-systemmonitor'],
    'quicksettings': ['brightnessctl'],
    'clipboard': ['wl-clipboard', 'cliphist'],
    'prescript': [],
    'cursor': ['librsvg', 'xorg-xcursorgen'],
}


def normalize(selected):
    unknown = selected - COMPONENTS.keys()
    if unknown:
        raise ValueError('Unknown component: ' + ', '.join(sorted(unknown)))
    if selected & {'shortcuts', 'quicksettings', 'clipboard', 'prescript'}:
        selected.add('desktop')
    if 'clipboard' in selected:
        selected.add('shortcuts')
    if not selected:
        raise ValueError('Choose at least one component')
    return selected


def run(command):
    subprocess.run([str(value) for value in command], check=True)


def optional_media_lines(selected, video=None):
    """Describe the same overlay/source precedence used by install-assets.py."""
    data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    overlay = data / 'index/assets'
    lines = [
        'The intro video and login background music are optional and not bundled.',
        'Add your own files at these exact paths before continuing:',
        '',
    ]
    for label, relative in (('Intro video', 'intro.mp4'), ('Login background music', 'sounds/bg.mp3')):
        supplied = next((root / relative for root in (overlay, SRC / 'assets')
                         if (root / relative).is_file()), None)
        lines += [label + ':', str(overlay / relative),
                  'Found: ' + str(supplied) if supplied else 'Not supplied (optional)', '']
    if video:
        lines += ['Selected intro override: ' + str(video), '']
    lines += [
        'Create parent folders if needed. You can copy files from another terminal, then press R to recheck.',
        'Source installs also accept assets/intro.mp4 and assets/sounds/bg.mp3 in the extracted project.',
        'No files yet? Continue: a fresh install skips the video and background music. Existing installed media is kept.',
        'Saved custom intro choices take priority; use Settings > Intro Video to change them.',
    ]
    if 'intro' not in selected:
        lines.append('Intro playback is off because the Intro video component is not selected.')
    lines.append('The INDEX wallpaper, logo, font and sound effects are included.')
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--components', help='Comma-separated names, or all')
    parser.add_argument('--list', action='store_true', help='List available components')
    parser.add_argument('--dry-run', action='store_true', help='Show the plan without changing anything')
    parser.add_argument('--no-packages', action='store_true', help='Use already-installed dependencies')
    parser.add_argument('--manager', choices=('pacman', 'yay'), default='pacman')
    parser.add_argument('--intro-video', type=Path, help='Use this video rather than the original intro')
    parser.add_argument('--default-intro', action='store_true', help='Use your optional assets/intro.mp4')
    parser.add_argument('--yes', action='store_true', help='Apply a specified plan without the final prompt')
    args = parser.parse_args()
    if args.list:
        for i, (name, label) in enumerate(COMPONENTS.items(), 1):
            print(f'{i:2}. {name:14} {label}')
        return
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'index/setup-selection.json'
    defaults = DEFAULT
    try:
        saved = json.loads(config.read_text())
        if isinstance(saved, list) and saved and set(saved) <= COMPONENTS.keys():
            defaults = saved
    except (OSError, ValueError):
        pass
    if args.components is None:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            parser.error('Use --components for non-interactive setup; --list shows the names')
        from setup_menu import choose_components
        selected = choose_components(COMPONENTS, defaults, normalize)
        if selected is None:
            print('Cancelled; nothing changed.')
            return
    else:
        selected = set(COMPONENTS) if args.components == 'all' else set(filter(None, args.components.split(',')))
    if args.intro_video:
        selected.add('intro')
        args.intro_video = args.intro_video.expanduser().resolve()
        if not args.intro_video.is_file():
            parser.error('Intro video file does not exist')
    if args.default_intro:
        if args.intro_video:
            parser.error('Choose either --intro-video or --default-intro')
        selected.add('intro')
    try:
        selected = normalize(selected)
    except ValueError as error:
        parser.error(str(error))
    has_media = bool(selected & {'desktop', 'login', 'intro'})
    interactive = sys.stdin.isatty() and sys.stdout.isatty()
    if has_media and interactive and not args.yes and not args.dry_run:
        from setup_menu import prepare_media
        if not prepare_media(lambda: optional_media_lines(selected, args.intro_video)):
            print('Cancelled; nothing changed.')
            return
    packages = list(dict.fromkeys(package for name in COMPONENTS if name in selected for package in PACKAGES[name]))
    print('\nSelected components:')
    for name in COMPONENTS:
        if name in selected:
            print('  + ' + COMPONENTS[name])
    print('\nDependencies: ' + ', '.join(packages))
    if args.intro_video:
        print('Intro video: ' + str(args.intro_video))
    print('Cursor activation: unchanged. Package creation/publication: not part of this setup.')
    media = optional_media_lines(selected, args.intro_video) if has_media else []
    if media:
        print('\nOptional video and music:')
        print('\n'.join(media))
    if 'desktop' in selected and 'login' not in selected:
        print('Desktop without Login: use your existing display manager (Plasma Wayland), '
              'or log in at a local text console and run startplasma-wayland. '
              'Setup will not enable a display manager.')
    if args.dry_run:
        print('\nPreview only; no changes made.')
        return
    if os.name != 'posix' or not shutil.which('pacman'):
        parser.error('Run the setup on Arch-based Linux with pacman available')
    if os.geteuid() == 0:
        parser.error('Run setup as your normal user; it requests sudo only where needed')
    if not args.yes:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            parser.error('Use --dry-run to review, then --yes to apply non-interactively')
        from setup_menu import confirm_install
        if not confirm_install(COMPONENTS, selected, packages, args.manager, args.no_packages, args.intro_video, media):
            print('Cancelled; nothing changed.')
            return
    if args.intro_video:
        # Reject unreadable media before installing packages or changing configuration.
        run([sys.executable, SRC / 'tools/index-intro.py', '--check-video', args.intro_video])
    if not args.no_packages and packages:
        if args.manager == 'yay':
            if not shutil.which('yay'):
                parser.error('yay is not installed; use --manager pacman')
            run(['yay', '-S', '--needed', *packages])
        else:
            run(['sudo', 'pacman', '-S', '--needed', *packages])
    features = ','.join(name for name in COMPONENTS if name in selected and name not in ('desktop', 'login', 'intro', 'cursor'))
    if 'desktop' in selected:
        run(['bash', SRC / 'install-desktop.sh', '--no-packages', '--features=' + features])
    else:
        extras = ','.join(name for name in ('terminals', 'fastfetch') if name in selected)
        if extras:
            run(['bash', SRC / 'tools/install-extras.sh', '--components', extras])
    if 'login' in selected:
        run(['bash', SRC / 'install-greeter.sh', '--no-packages'])
    if selected & {'desktop', 'login', 'intro'}:
        scope = 'both' if 'desktop' in selected and 'login' in selected else 'login' if 'login' in selected else 'user' if 'desktop' in selected else 'both'
        intro = ['--video', args.intro_video] if args.intro_video else ['--default'] if args.default_intro else ['--enable'] if 'intro' in selected else ['--disable']
        run([sys.executable, SRC / 'tools/index-intro.py', '--scope', scope, *intro])
    if 'cursor' in selected:
        import tempfile

        data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
        destination = data / 'icons/INDEX-Needle'
        destination.parent.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix='.INDEX-Needle-stage-', dir=destination.parent))
        candidate = stage / 'INDEX-Needle'
        backup = stage / 'previous-INDEX-Needle'
        run(['bash', SRC / 'cursor/index-needle/build.sh', candidate])
        had_previous = destination.exists() or destination.is_symlink()
        if had_previous:
            destination.rename(backup)
        try:
            candidate.rename(destination)
        except BaseException:
            if had_previous:
                try:
                    backup.rename(destination)
                except OSError as error:
                    raise OSError(f'Cursor promotion and rollback failed; previous theme retained at {backup}') from error
            raise
        if had_previous:
            print(f'Previous cursor files retained at {backup}')
        print('Cursor files installed for review. Your active pointer has not changed.')
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps([name for name in COMPONENTS if name in selected], indent=2) + '\n')
    print('\nSetup finished. Log out/in for desktop changes; reboot for login-screen changes.')
    if 'desktop' in selected:
        print('Change intro videos in Win+A > Settings > Intro Video.')
        if 'login' not in selected:
            print('To start without a display manager: log in at a local text console, '
                  'then run startplasma-wayland.')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        raise SystemExit('\nCancelled.')
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Setup failed: {error}')
