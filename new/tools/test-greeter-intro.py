#!/usr/bin/env python3
"""Run the launcher's real boot-claim block in isolated directories, never cage.

Run: python3 new/tools/test-greeter-intro.py
Requires a local POSIX sh (Git for Windows sh is also supported).
"""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


LAUNCHER = Path(__file__).resolve().parents[1] / 'greeter/run-greeter'
INSTALLER = LAUNCHER.parent.parent / 'install-greeter.sh'
SH = shutil.which('sh')
if SH is None and os.name == 'nt':
    git_sh = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/usr/bin/sh.exe'
    if git_sh.is_file():
        SH = str(git_sh)
BOOT_A = '11111111-1111-4111-8111-111111111111'
BOOT_B = '22222222-2222-4222-8222-222222222222'


@unittest.skipUnless(SH, 'A local POSIX sh is required; no WSL/VM is used')
class BootClaimTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='index-boot-claim-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.assertTrue(self.root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.state = self.root / 'persistent state'
        self.state.mkdir(mode=0o700)
        source = LAUNCHER.read_text(encoding='utf-8')
        block = source[source.index('export INDEX_INTRO_BOOT=0'):source.index('# virtual GPUs')]
        # Only kernel identity is stubbed; mkdir and the claim logic are real.
        self.script = ('cat() { [ "$1" = /proc/sys/kernel/random/boot_id ] || return 91; '
                       'printf "%s\\n" "$TEST_BOOT_ID"; }\n'
                       + block + '\nprintf "%s\\n" "$INDEX_INTRO_BOOT"\n')
        self.env = dict(os.environ, XDG_CACHE_HOME=(self.root / 'cache with spaces').as_posix(),
                        XDG_RUNTIME_DIR='', INDEX_INTRO_BOOT='inherited-value',
                        INDEX_GREETER_INTRO_STATE_DIR=self.state.as_posix())
        # Directly launching Git's sh does not add its coreutils to Windows PATH.
        self.env['PATH'] = str(Path(SH).parent) + os.pathsep + self.env.get('PATH', '')

    def claim(self, boot=BOOT_A, **overrides):
        result = subprocess.run([SH, '-c', self.script],
                                env=dict(self.env, TEST_BOOT_ID=boot, **overrides),
                                capture_output=True, text=True, timeout=15, check=True)
        self.assertEqual(result.stderr, '')
        return result.stdout.strip()

    def test_same_boot_claimed_once_and_new_boot_claimed_again(self):
        self.assertEqual(self.claim(), '1')
        self.assertEqual(self.claim(), '0')
        self.assertEqual(self.claim(BOOT_B), '1')
        self.assertEqual(self.claim(BOOT_B), '0')

    def test_concurrent_launches_have_exactly_one_winner(self):
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.claim(), range(8)))
        self.assertEqual(results.count('1'), 1)
        self.assertEqual(results.count('0'), 7)

    def test_runtime_and_cache_cleanup_do_not_reset_persistent_claim(self):
        runtime = self.root / 'runtime with spaces'
        cache = self.root / 'cache with spaces'
        runtime.mkdir()
        cache.mkdir()
        (cache / 'qt-cache').write_text('temporary Qt data', encoding='utf-8')
        self.assertEqual(self.claim(XDG_RUNTIME_DIR=runtime.as_posix()), '1')
        runtime.rmdir()
        (cache / 'qt-cache').unlink()
        cache.rmdir()
        runtime.mkdir()
        cache.mkdir()
        self.assertEqual(self.claim(XDG_RUNTIME_DIR=runtime.as_posix()), '0')
        self.assertTrue((self.state / BOOT_A).is_dir())
        self.assertFalse(list(runtime.iterdir()))
        self.assertFalse(list(cache.iterdir()))

    def test_missing_runtime_does_not_prevent_persistent_claim(self):
        self.assertEqual(self.claim(XDG_RUNTIME_DIR=(self.root / 'absent').as_posix()), '1')
        self.assertTrue((self.state / BOOT_A).is_dir())

    def test_absent_state_fails_closed_without_creating_parent(self):
        absent = self.root / 'absent state'
        self.assertEqual(self.claim(INDEX_GREETER_INTRO_STATE_DIR=absent.as_posix()), '0')
        self.assertFalse(absent.exists())

    def test_invalid_identity_skips_without_creating_state(self):
        for boot in ('', '../../escape', 'not-a-boot-id', 'A' * 36):
            with self.subTest(boot=boot):
                self.assertEqual(self.claim(boot), '0')
                self.assertFalse((self.root / 'cache with spaces').exists())
                self.assertFalse(list(self.state.iterdir()))

    def test_unwritable_state_skips_without_blocking_launcher(self):
        blocked = self.root / 'not-a-directory'
        blocked.write_text('keep', encoding='utf-8')
        self.assertEqual(self.claim(INDEX_GREETER_INTRO_STATE_DIR=blocked.as_posix()), '0')
        self.assertEqual(blocked.read_text(encoding='utf-8'), 'keep')

    def test_failed_marker_creation_fails_closed(self):
        self.script = 'mkdir() { return 1; }\n' + self.script
        self.assertEqual(self.claim(), '0')
        self.assertFalse(list(self.state.iterdir()))

    def test_installer_provisions_only_persistent_intro_directory_after_packages(self):
        source = INSTALLER.read_text(encoding='utf-8')
        command = next(line for line in source.splitlines() if line.startswith('sudo install -d'))
        self.assertLess(source.index('sudo pacman -S'), source.index(command))
        self.assertLess(source.index(command), source.index('step "Installing the INDEX greeter'))
        # Execute only this command with stubs, never the installer or real sudo.
        script = ('id() { [ "$1" = -gn ] && [ "$2" = greeter ] || return 91; '
                  'printf "%s\\n" greeter-group; }\n'
                  'sudo() { printf "%s\\n" "$@"; }\n' + command)
        result = subprocess.run([SH, '-c', script], env=self.env,
                                capture_output=True, text=True, timeout=15, check=True)
        self.assertEqual(result.stdout.splitlines(),
                         ['install', '-d', '-m', '700', '-o', 'greeter', '-g',
                          'greeter-group', '/var/lib/index-greeter-intro'])
        launcher = LAUNCHER.read_text(encoding='utf-8')
        self.assertIn('${INDEX_GREETER_INTRO_STATE_DIR:-/var/lib/index-greeter-intro}', launcher)

    def test_disabled_or_always_launch_still_consumes_boot_claim(self):
        self.assertEqual(self.claim(INDEX_INTRO='0'), '1')
        self.assertEqual(self.claim(INDEX_INTRO='1'), '0')


if __name__ == '__main__':
    unittest.main()
