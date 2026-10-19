#!/usr/bin/env python3
"""Choose the intro video for installed INDEX lock/login screens."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


SCOPES = ('user', 'login')
LOGIN_TARGET = Path('/usr/share/index-greeter')


def default_choice(scope):
    choice = {'enabled': True, 'custom': False}
    if scope == 'login':
        choice['frequency'] = 'boot'
    return choice


def read_choice(config, scope):
    saved = json.loads(config.read_text())
    if not isinstance(saved, dict):
        raise ValueError(f'Invalid intro settings: {config}')
    choice = {key: bool(saved.get(key, default))
              for key, default in (('enabled', True), ('custom', False))}
    if scope == 'login':
        frequency = saved.get('frequency', 'boot')
        if frequency not in ('boot', 'always'):
            raise ValueError(f'Invalid login intro frequency: {config}')
        choice['frequency'] = frequency
    return choice


def save_choice(config, choice):
    config.parent.mkdir(parents=True, exist_ok=True)
    staged = config.with_suffix('.json.tmp')
    staged.write_text(json.dumps(choice, indent=2) + '\n')
    staged.replace(config)


def cache_video(video, custom):
    if video.resolve() != custom.resolve():
        custom.parent.mkdir(parents=True, exist_ok=True)
        staged = custom.with_name('video.tmp')
        shutil.copyfile(video, staged)
        staged.replace(custom)


def validate_video(path, parser):
    video = path.expanduser().resolve(strict=True)
    if not video.is_file():
        parser.error('Choose a regular video file')
    if not shutil.which('ffprobe'):
        parser.error('ffprobe is required to check videos; install ffmpeg with pacman')
    probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                            '-show_entries', 'stream=codec_type', '-of', 'csv=p=0', str(video)],
                           capture_output=True, text=True, timeout=30)
    if probe.returncode or probe.stdout.strip() != 'video':
        parser.error('That file does not contain a readable video stream')
    return video


def installed(data, scope):
    if scope == 'login':
        return (LOGIN_TARGET / 'greeter.qml').is_file()
    return any((data / package / 'org.index.desktop/contents/lockscreen/LockScreen.qml').is_file()
               for package in ('plasma/shells', 'plasma/look-and-feel'))


def screen_targets(data, scope):
    if scope == 'login':
        return [(LOGIN_TARGET, True)]
    return [(data / package / 'org.index.desktop/contents/lockscreen', False)
            for package in ('plasma/shells', 'plasma/look-and-feel')]


def video_available(data, state, choice, scope):
    if choice['custom']:
        custom = state / scope / 'video'
        if not (state / scope / 'settings.json').exists():
            custom = state / 'video'
        return custom.is_file()
    return any((target / 'assets/intro.mp4').is_file()
               for target, _ in screen_targets(data, scope))


def authorize_login(parser):
    askpass = Path(__file__).resolve().with_name('index-askpass.sh')
    if not askpass.is_file() or not os.access(askpass, os.X_OK):
        parser.error('Login intro authorization requires an executable index-askpass.sh beside this helper')
    if not shutil.which('kdialog'):
        parser.error('kdialog is required for login intro authorization; install kdialog with pacman')
    env = dict(os.environ, SUDO_ASKPASS=str(askpass))
    try:
        subprocess.run(['sudo', '-A', '-v'], env=env, check=True)
    except subprocess.CalledProcessError:
        parser.error('Login intro authorization cancelled or failed; no intro settings were changed')
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--video', type=Path, help='Use an MP4, WebM, MKV or MOV video')
    action.add_argument('--disable', action='store_true', help='Go directly to the password screen')
    action.add_argument('--default', action='store_true', help='Use your optional assets/intro.mp4; skip when absent')
    action.add_argument('--enable', action='store_true')
    action.add_argument('--apply', action='store_true', help='Reapply the saved choice after setup')
    action.add_argument('--status', action='store_true')
    action.add_argument('--check-video', type=Path, help='Validate a video without changing settings')
    parser.add_argument('--gui', action='store_true',
                        help='Check installed screens and use a password dialog for login changes')
    parser.add_argument('--scope', choices=('user', 'login', 'both'), default='both',
                        help='user = lock screen; login = greeter (requires sudo)')
    parser.add_argument('--frequency', choices=('boot', 'always'),
                        help='Login only: once per boot (default) or every login; requires --scope login')
    args = parser.parse_args()
    if args.frequency is not None:
        if args.scope != 'login':
            parser.error('--frequency requires --scope login')
        if args.status or args.check_video:
            parser.error('--frequency cannot be combined with --status or --check-video')
    # Validation must not read, migrate or write any saved choice.
    if args.check_video:
        validate_video(args.check_video, parser)
        print('Video is readable')
        return
    video = validate_video(args.video, parser) if args.video else None
    data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    state = data / 'index/intro'
    scopes = SCOPES if args.scope == 'both' else (args.scope,)
    if args.gui and not args.status:
        for scope in scopes:
            if not installed(data, scope):
                parser.error(f'INDEX {scope} screen is not installed; install it before changing its intro')
    missing = {scope for scope in SCOPES if not (state / scope / 'settings.json').exists()}
    legacy = state / 'settings.json'
    migrate = missing if missing and legacy.exists() else set()
    old_choices = {scope: read_choice(legacy, scope) if scope in migrate else default_choice(scope)
                   for scope in SCOPES}
    choices = {scope: read_choice(state / scope / 'settings.json', scope) if scope not in missing
               else old_choices[scope].copy() for scope in SCOPES if scope in scopes or scope in migrate}
    if args.status:
        print(json.dumps({scope: dict(choices[scope], installed=installed(data, scope),
                                     available=video_available(data, state, choices[scope], scope))
                          if args.gui else choices[scope] for scope in scopes}, indent=2))
        return
    for scope in scopes:
        choice = choices[scope]
        if video:
            choice.update(enabled=True, custom=True)
        elif args.disable:
            choice['enabled'] = False
        elif args.default:
            choice.update(enabled=True, custom=False)
        elif args.enable:
            choice['enabled'] = True
        if args.frequency is not None:
            choice['frequency'] = args.frequency
        choices[scope] = choice
        custom = state / 'video' if scope in migrate else state / scope / 'video'
        if choice['enabled'] and choice['custom'] and video is None and not custom.is_file():
            parser.error(f'Saved {scope} custom video is missing; select a video or use --default')
    # Authorize before even legacy migration: cancellation must leave every byte intact.
    sudo_env = authorize_login(parser) if args.gui and 'login' in scopes else None
    # Seed both scopes once, copying bytes rather than sharing a mutable cache.
    # Keep legacy files intact for recovery; scoped files take precedence thereafter.
    for scope in SCOPES:
        if scope in migrate:
            if old_choices[scope]['custom'] and (state / 'video').is_file():
                cache_video(state / 'video', state / scope / 'video')
            save_choice(state / scope / 'settings.json', old_choices[scope])
    for scope in scopes:
        if video:
            cache_video(video, state / scope / 'video')
        save_choice(state / scope / 'settings.json', choices[scope])

    for scope in scopes:
        apply_choice(data, state / scope / 'video', choices[scope], scope, sudo_env)


def apply_choice(data, custom, choice, scope, sudo_env=None):
    # Only fixed filenames enter QML. User paths are copied as data, never code.
    filename = 'intro-user.mp4' if choice['custom'] else 'intro.mp4'
    frequency_qml = ('    property bool oncePerBoot: '
                     + str(choice.get('frequency', 'boot') == 'boot').lower() + '\n'
                     if scope == 'login' else '')
    targets = screen_targets(data, scope)
    applied = 0
    for target, privileged in targets:
        if not ((target / 'LockScreen.qml').is_file() or (target / 'greeter.qml').is_file()):
            continue
        available = custom.is_file() if choice['custom'] else (target / 'assets/intro.mp4').is_file()
        enabled = choice['enabled'] and available
        source = 'Qt.resolvedUrl("assets/' + filename + '")' if available else '""'
        qml = ('import QtQml\nQtObject {\n'
               '    property bool enabled: ' + str(enabled).lower() + '\n'
               + frequency_qml + '    property url videoSource: ' + source + '\n}\n')
        if privileged:
            sudo = ['sudo'] + (['-A'] if (sudo_env or os.environ).get('SUDO_ASKPASS') else [])
            options = {'env': sudo_env} if sudo_env is not None else {}
            with tempfile.TemporaryDirectory(prefix='index-intro-') as temp:
                generated = Path(temp) / 'IntroConfig.qml'
                generated.write_text(qml)
                if choice['custom'] and custom.is_file():
                    subprocess.run(sudo + ['install', '-m', '644', str(custom), str(target / 'assets/intro-user.mp4')], check=True, **options)
                subprocess.run(sudo + ['install', '-m', '644', str(generated), str(target / 'IntroConfig.qml')], check=True, **options)
        else:
            if choice['custom'] and custom.is_file():
                (target / 'assets').mkdir(parents=True, exist_ok=True)
                shutil.copyfile(custom, target / 'assets/intro-user.mp4')
            (target / 'IntroConfig.qml').write_text(qml)
        applied += 1
    available = video_available(data, data / 'index/intro', choice, scope)
    print(scope + ': ' + ('Intro disabled' if not choice['enabled'] else 'No video supplied; intro skipped' if not available else 'Custom intro selected' if choice['custom'] else 'User-supplied assets/intro.mp4 selected')
          + f' ({applied} installed screen(s) updated)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Intro setup failed: {error}')
