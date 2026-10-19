#!/usr/bin/env python3
"""Isolated asset and installer-copy tests; no real KDE, sudo or system writes.

Run: python3 -B tools/test-install-assets.py
Set INDEX_TEST_BASH if needed (Windows Git Bash is auto-detected).
"""
from contextlib import redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('index_assets', SOURCE / 'tools/install-assets.py')
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)
FONT = 'PerfectDOSVGA437-Universal.ttf'
LOCK_MEDIA = ('Logo.png', 'Power.png', 'Restart.png', 'intro.mp4',
              'sounds/bg.mp3', 'sounds/click.wav', 'sounds/check.wav',
              'sounds/fail.wav', 'sounds/success.wav')
DESKTOP_MEDIA = ('wall.png', 'sounds/ui/notify.wav', 'sounds/ui/tick.wav',
                 'sounds/ui/connect.wav', 'sounds/ui/disconnect.wav',
                 'sounds/ui/menu.wav', 'sounds/ui/error.wav', 'sounds/ui/scramble.mp3')
BASH = os.environ.get('INDEX_TEST_BASH')
if not BASH and os.name == 'nt':
    candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe'
    if candidate.is_file():
        BASH = str(candidate)
BASH = BASH or shutil.which('bash')


class AssetTests(unittest.TestCase):
    def setUp(self):
        fixture = tempfile.TemporaryDirectory(prefix='index-assets-test-')
        self.addCleanup(fixture.cleanup)
        self.root = Path(fixture.name)
        self.source = self.root / 'source with spaces'
        self.config = self.root / 'custom config'
        self.data = self.root / 'custom data'
        self.overlay = self.data / 'index/assets'
        self.qs = self.config / 'quickshell/index'
        self.lnf = self.data / 'plasma/look-and-feel/org.index.desktop/contents'
        self.locks = (self.qs / 'lock/assets',
                      self.data / 'plasma/shells/org.index.desktop/contents/lockscreen/assets',
                      self.lnf / 'lockscreen/assets')
        self.login = self.root / 'system/usr/share/index-greeter/assets'
        self.write(self.source / 'assets' / FONT, 'canonical user-modified font')

    @staticmethod
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf-8', newline='\n')

    @staticmethod
    def tree(root):
        return {p.relative_to(root).as_posix(): p.read_text(encoding='utf-8')
                for p in root.rglob('*') if p.is_file()}

    def install(self, scope='user'):
        return assets.install_assets(self.source, self.config, self.data, scope)

    def test_canonical_font_reaches_all_loaders_with_no_optional_assets_or_dirs(self):
        with mock.patch.object(assets.subprocess, 'run') as sudo:
            self.assertEqual(self.install(), 4)
        sudo.assert_not_called()
        for target in (*self.locks, self.data / 'fonts/index'):
            self.assertEqual(self.tree(target), {FONT: 'canonical user-modified font'})
        self.assertFalse((self.qs / 'assets').exists())
        self.assertFalse((self.lnf / 'assets').exists())
        self.assertFalse(self.overlay.exists())

    def test_whitelist_destinations_and_per_file_user_overlay(self):
        for relative in (*LOCK_MEDIA, *DESKTOP_MEDIA):
            self.write(self.source / 'assets' / relative, 'source ' + relative)
        for relative in ('Logo.png', 'intro.mp4', 'sounds/bg.mp3', 'wall.png', 'sounds/ui/tick.wav'):
            self.write(self.overlay / relative, 'overlay ' + relative)
        self.write(self.overlay / FONT, 'must never override canonical font')
        self.install()
        expected_locks = {relative: ('overlay ' if (self.overlay / relative).exists() else 'source ') + relative
                          for relative in LOCK_MEDIA}
        expected_locks[FONT] = 'canonical user-modified font'
        for target in self.locks:
            self.assertEqual(self.tree(target), expected_locks)
        self.assertEqual(self.tree(self.qs / 'assets'), {
            relative: ('overlay ' if (self.overlay / relative).exists() else 'source ') + relative
            for relative in DESKTOP_MEDIA})
        self.assertEqual(self.tree(self.lnf / 'assets'), {'Logo.png': 'overlay Logo.png'})
        self.assertEqual(self.tree(self.data / 'fonts/index'), {FONT: 'canonical user-modified font'})

    def test_unlisted_files_fonts_profile_photos_and_legacy_copies_are_ignored(self):
        for root in (self.source / 'assets', self.overlay,
                     self.source / 'quickshell/lock/assets', self.source / 'greeter/assets'):
            for relative in ('DefaultProfile.jpg', 'DefaultProfile.png', 'other.png', 'other.ttf',
                             'PerfectDOSVGA437.ttf', 'PerfectDOSVGA437-Thai-v2.ttf', 'other.otf',
                             'intro-user.mp4', 'sounds/ui/extra.wav', 'sounds/nested/click.wav'):
                self.write(root / relative, 'excluded')
        # A directory with a whitelisted name is also absent media.
        (self.overlay / 'Logo.png').mkdir()
        self.install()
        for target in self.locks:
            self.assertEqual(self.tree(target), {FONT: 'canonical user-modified font'})
        self.assertEqual(self.tree(self.data / 'fonts/index'), {FONT: 'canonical user-modified font'})
        self.assertFalse((self.qs / 'assets').exists())

    def test_rerun_preserves_custom_intro_settings_and_video(self):
        for target in self.locks:
            self.write(target / 'intro-user.mp4', 'saved custom video')
            self.write(target.parent / 'IntroConfig.qml', 'saved custom selection')
        state = self.data / 'index/intro/user/settings.json'
        self.write(state, '{"enabled": false, "custom": true}')
        self.write(self.source / 'assets/intro.mp4', 'optional default intro')
        self.write(self.overlay / 'intro-user.mp4', 'must never be copied')
        self.install()
        self.install()
        for target in self.locks:
            self.assertEqual((target / 'intro-user.mp4').read_text(), 'saved custom video')
            self.assertEqual((target.parent / 'IntroConfig.qml').read_text(), 'saved custom selection')
            self.assertEqual((target / 'intro.mp4').read_text(), 'optional default intro')
        self.assertEqual(state.read_text(), '{"enabled": false, "custom": true}')
        # Removing optional input is not a request to delete installed media.
        (self.source / 'assets/intro.mp4').unlink()
        self.install()
        self.assertEqual((self.locks[0] / 'intro.mp4').read_text(), 'optional default intro')

    def privileged_install(self):
        def sudo(command, *, check):
            self.assertTrue(check)
            self.assertEqual(len(command), 7)
            self.assertEqual(command[:5], ['sudo', 'install', '-D', '-m', '644'])
            self.assertTrue(Path(command[6]).is_relative_to(self.login))
            target = Path(command[6])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(command[5], target)

        with mock.patch.object(assets, 'LOGIN_ASSETS', self.login), \
                mock.patch.object(assets.subprocess, 'run', side_effect=sudo) as calls:
            self.install('login')
        return calls

    def test_login_empty_assets_creates_font_via_privileged_install(self):
        calls = self.privileged_install()
        self.assertEqual(calls.call_count, 1)
        self.assertEqual(self.tree(self.login), {FONT: 'canonical user-modified font'})
        self.assertFalse(self.config.exists())

    def test_login_overlay_and_saved_intro_with_only_required_privileged_writes(self):
        for relative in (*LOCK_MEDIA, *DESKTOP_MEDIA, 'DefaultProfile.jpg', 'other.ttf'):
            self.write(self.source / 'assets' / relative, 'source ' + relative)
        self.write(self.overlay / 'Logo.png', 'user logo')
        self.write(self.overlay / FONT, 'wrong font')
        self.write(self.overlay / 'intro-user.mp4', 'wrong custom video')
        self.write(self.login / 'intro-user.mp4', 'saved login video')
        self.write(self.login.parent / 'IntroConfig.qml', 'saved login selection')
        self.privileged_install()
        expected = {relative: 'source ' + relative for relative in LOCK_MEDIA}
        expected.update({FONT: 'canonical user-modified font', 'Logo.png': 'user logo',
                         'intro-user.mp4': 'saved login video'})
        self.assertEqual(self.tree(self.login), expected)
        self.assertEqual((self.login.parent / 'IntroConfig.qml').read_text(), 'saved login selection')

    def test_missing_canonical_font_fails_before_any_copy(self):
        (self.source / 'assets' / FONT).unlink()
        with self.assertRaisesRegex(FileNotFoundError, 'Missing canonical INDEX font'):
            self.install()
        self.assertFalse(self.config.exists())
        self.assertFalse(self.data.exists())

    def test_cli_uses_fixed_overlay_and_xdg_or_home_defaults(self):
        for use_xdg in (True, False):
            with self.subTest(use_xdg=use_xdg):
                home = self.root / ('xdg home' if use_xdg else 'fallback home')
                config = self.config if use_xdg else home / '.config'
                data = self.data if use_xdg else home / '.local/share'
                self.write(data / 'index/assets/wall.png', 'user wallpaper')
                env = {'XDG_CONFIG_HOME': str(config) if use_xdg else '',
                       'XDG_DATA_HOME': str(data) if use_xdg else ''}
                with mock.patch.dict(os.environ, env), \
                        mock.patch.object(Path, 'home', return_value=home), \
                        mock.patch.object(assets, '__file__', str(self.source / 'tools/install-assets.py')), \
                        mock.patch.object(sys, 'argv', ['install-assets.py', '--scope', 'user']), \
                        redirect_stdout(io.StringIO()):
                    assets.main()
                self.assertEqual((config / 'quickshell/index/assets/wall.png').read_text(), 'user wallpaper')
                self.assertEqual((data / 'fonts/index' / FONT).read_text(), 'canonical user-modified font')


@unittest.skipUnless(BASH, 'bash required for installer copy blocks')
class InstallerCopyTests(unittest.TestCase):
    """Execute real copy blocks only, with external commands isolated/stubbed."""
    def setUp(self):
        fixture = tempfile.TemporaryDirectory(prefix='index-assets-installer-test-')
        self.addCleanup(fixture.cleanup)
        self.root = Path(fixture.name)
        self.source = self.root / 'source'
        self.bin = self.root / 'bin'
        self.calls = self.root / 'calls'
        for relative in ('quickshell/shell.qml', 'bridge/index-kwin-bridge',
                         'tools/index-intro.py', 'tools/index-askpass.sh',
                         'kde/aurorae/index/indexrc', 'kde/color-schemes/IndexDark.colors',
                         'kde/look-and-feel/org.index.desktop/contents/lockscreen/LockScreen.qml',
                         'kde/shells/org.index.desktop/metadata.json', 'greeter/greeter.qml',
                         'greeter/run-greeter'):
            AssetTests.write(self.source / relative, 'fixture')
        for name, body in {
            'fc-cache': 'exit 0',
            'python3': 'printf "%s\\n" "$*" >> "$TEST_CALLS"; exit "${TEST_HELPER_EXIT:-0}"',
            'sudo': 'exec "$@"',
        }.items():
            path = self.bin / name
            AssetTests.write(path, '#!/usr/bin/env bash\nset -euo pipefail\n' + body + '\n')
            path.chmod(0o755)

    def run_block(self, login=False, fail=False):
        name = 'install-greeter.sh' if login else 'install-desktop.sh'
        text = (SOURCE / name).read_text(encoding='utf-8')
        start = 'step "Installing the INDEX greeter to $DEST"' if login else 'step "Copying Quickshell config"'
        end = 'step "Configuring greetd"' if login else '#  4. Apply settings'
        block = text[text.index(start):text.index(end)]
        prelude = '''#!/usr/bin/env bash
set -euo pipefail
if command -v cygpath >/dev/null; then
    TEST_ROOT=$(cygpath -u "$TEST_ROOT")
fi
export PATH="$TEST_ROOT/bin:$PATH"
SRC="$TEST_ROOT/source"
CFG="$TEST_ROOT/config"
DATA="$TEST_ROOT/data"
IDX="$DATA/index"
DEST="$TEST_ROOT/login"
LOGIN_USER=fixture
FEATURES=''
step() { :; }
info() { :; }
fresh_dir() { rm -rf "${1:?}"; mkdir -p "$(dirname "${1:?}")"; }
has_feature() { return 1; }
'''
        script = self.root / name
        AssetTests.write(script, prelude + block + '\nprintf "COPY COMPLETE\\n"\n')
        env = dict(os.environ, TEST_ROOT=self.root.as_posix(), TEST_CALLS=self.calls.as_posix(),
                   TEST_HELPER_EXIT='17' if fail else '0')
        result = subprocess.run([BASH, str(script)], env=env, capture_output=True, text=True)
        if fail:
            self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
            self.assertNotIn('COPY COMPLETE', result.stdout)
        else:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('COPY COMPLETE', result.stdout)
        self.assertIn('tools/install-assets.py --scope ' + ('login' if login else 'user'),
                      self.calls.read_text())

    def test_desktop_copy_block_accepts_all_missing_asset_directories(self):
        self.run_block()

    def test_login_copy_block_accepts_all_missing_asset_directories(self):
        self.run_block(login=True)

    def test_desktop_helper_failure_stops_installer(self):
        self.run_block(fail=True)

    def test_login_helper_failure_stops_installer(self):
        self.run_block(login=True, fail=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
