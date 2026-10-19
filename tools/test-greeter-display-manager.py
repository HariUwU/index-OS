#!/usr/bin/env python3
"""Exercise real display-manager detection/restore blocks with isolated files."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'install-greeter.sh').read_text(encoding='utf-8')
BASH = shutil.which('bash')


@unittest.skipUnless(os.name == 'posix' and BASH, 'Run on Linux with Bash')
class DisplayManagerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='index-display-manager-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.alias = self.root / 'display-manager.service'
        self.state = self.root / 'state'
        self.state.mkdir()
        begin = SOURCE.index('current_dm() {')
        end = SOURCE.index('\n}', begin) + 2
        self.detect = SOURCE[begin:end].replace(
            '/etc/systemd/system/display-manager.service', shlex.quote(self.alias.as_posix()))
        self.env = dict(os.environ)

    def run_shell(self, body):
        return subprocess.run([BASH, '-c', 'set -euo pipefail\n' + self.detect + '\n' + body],
                              env=self.env, capture_output=True, text=True, timeout=15)

    def make_manager(self, name):
        target = self.root / name
        target.touch()
        self.alias.unlink(missing_ok=True)
        try:
            self.alias.symlink_to(target)
        except OSError as error:
            self.skipTest(f'Symlink creation unavailable: {error}')

    def save_previous(self):
        begin = SOURCE.index('old="$(current_dm)"')
        end = SOURCE.index('[ -f /etc/greetd/config.toml ]', begin)
        return self.run_shell('STATE=' + shlex.quote(self.state.as_posix()) + '\n'
                              + 'sudo() { "$@"; }; info() { :; }\n' + SOURCE[begin:end])

    def restore(self, previous):
        if previous is not None:
            (self.state / 'previous-dm').write_text(previous + '\n')
        begin = SOURCE.index('if [ "$DO_RESTORE" = 1 ]; then')
        end = SOURCE.index('step "Installing greetd and cage"', begin)
        return self.run_shell('STATE=' + shlex.quote(self.state.as_posix()) + '\n'
                              + 'DO_RESTORE=1\nstep() { :; }; info() { :; }\n'
                              + 'die() { printf "%s\\n" "$*" >&2; exit 1; }\n'
                              + 'sudo() { printf "SUDO"; printf " %s" "$@"; printf "\\n"; }\n'
                              + 'lock_on_start() { printf "LOCK %s\\n" "$1"; }\n'
                              + SOURCE[begin:end])

    def test_missing_alias_is_not_a_display_manager(self):
        result = self.run_shell('current_dm')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_real_manager_is_detected(self):
        self.make_manager('sddm.service')
        result = self.run_shell('current_dm')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'sddm.service')

    def test_fresh_install_records_none_and_repairs_failed_detection_record(self):
        (self.state / 'previous-dm').write_text('display-manager.service\n')
        result = self.save_previous()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / 'previous-dm').read_text().strip(), 'none')

    def test_reinstall_preserves_none_while_greetd_is_active(self):
        self.make_manager('greetd.service')
        (self.state / 'previous-dm').write_text('none\n')
        result = self.save_previous()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / 'previous-dm').read_text().strip(), 'none')

    def test_restore_none_disables_greetd_without_enabling_a_fake_unit(self):
        result = self.restore('none')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['SUDO systemctl disable greetd.service', 'LOCK true'])

    def test_restore_existing_manager_reenables_it(self):
        result = self.restore('sddm.service')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['SUDO systemctl disable greetd.service',
                                                     'SUDO systemctl enable sddm.service', 'LOCK true'])

    def test_restore_without_a_record_does_not_change_services(self):
        result = self.restore(None)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SUDO', result.stdout)


if __name__ == '__main__':
    unittest.main()
