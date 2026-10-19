#!/usr/bin/env python3
"""Exercise console setup orchestration with stub commands and temporary config.

Run: python3 -B new/tools/test-setup-prerequisites.py
No packages, desktop settings or services are changed.
"""
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location('index_setup', Path(__file__).with_name('setup.py'))
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class ConsolePrerequisitesTests(unittest.TestCase):
    def setUp(self):
        fixture = tempfile.TemporaryDirectory(prefix='index-prerequisites-test-')
        self.addCleanup(fixture.cleanup)
        self.root = Path(fixture.name)
        self.selection = self.root / 'index/setup-selection.json'
        self.commands = []
        self.output = io.StringIO()

    def apply(self, components, *options, fail_packages=False):
        def stub_run(command):
            self.commands.append([str(value) for value in command])
            if fail_packages and command[:2] == ['sudo', 'pacman']:
                raise subprocess.CalledProcessError(1, command)

        platform = SimpleNamespace(name='posix', geteuid=lambda: 1000,
                                   environ=dict(os.environ, XDG_CONFIG_HOME=str(self.root)))
        with mock.patch.object(setup, 'os', platform), \
                mock.patch.object(setup.shutil, 'which', return_value='/usr/bin/pacman'), \
                mock.patch.object(setup, 'run', side_effect=stub_run), \
                mock.patch.object(sys, 'argv', ['setup.py', '--components', components, '--yes', *options]), \
                redirect_stdout(self.output):
            setup.main()

    def test_fresh_desktop_login_installs_prerequisites_before_configuration(self):
        self.apply('desktop,login')
        package_command = self.commands[0]
        self.assertEqual(package_command[:4], ['sudo', 'pacman', '-S', '--needed'])
        packages = package_command[4:]
        self.assertTrue({'plasma-desktop', 'plasma-workspace', 'kwin', 'kconfig', 'qt6-tools',
                         'quickshell', 'dolphin', 'pipewire-pulse', 'wireplumber',
                         'kscreen', 'plasma-nm', 'plasma-pa', 'bluedevil', 'greetd', 'cage'} <= set(packages))
        self.assertEqual(len(packages), len(set(packages)), 'No repeated package arguments')
        self.assertEqual(self.commands[1], ['bash', str(setup.SRC / 'install.sh'),
                                            '--no-packages', '--features='])
        self.assertEqual(self.commands[2], ['bash', str(setup.SRC / 'install-greeter.sh'), '--no-packages'])
        self.assertEqual(self.commands[3][-3:], ['--scope', 'both', '--disable'])
        self.assertEqual(json.loads(self.selection.read_text()), ['desktop', 'login'])

    def test_desktop_alone_preserves_display_manager_choice_and_disabled_features(self):
        self.apply('desktop')
        self.assertNotIn('greetd', self.commands[0])
        self.assertNotIn('cage', self.commands[0])
        self.assertFalse(any('install-greeter.sh' in ' '.join(command) for command in self.commands))
        self.assertEqual(self.commands[1][-1], '--features=')
        self.assertEqual(self.commands[2][-3:], ['--scope', 'user', '--disable'])
        self.assertIn('startplasma-wayland', self.output.getvalue())
        self.assertEqual(json.loads(self.selection.read_text()), ['desktop'])

    def test_independent_fastfetch_does_not_install_desktop_or_login(self):
        self.apply('fastfetch')
        self.assertEqual(self.commands[0], ['sudo', 'pacman', '-S', '--needed', 'fastfetch'])
        self.assertEqual(self.commands[1], ['bash', str(setup.SRC / 'tools/install-extras.sh'),
                                            '--components', 'fastfetch'])
        self.assertEqual(len(self.commands), 2)

    def test_package_failure_stops_before_applying_settings_or_saving_selection(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.apply('desktop,login', fail_packages=True)
        self.assertEqual(len(self.commands), 1)
        self.assertFalse(self.selection.exists())

    def test_dry_run_does_not_run_commands_or_write_config(self):
        self.apply('desktop', '--dry-run')
        self.assertFalse(self.commands)
        self.assertFalse(list(self.root.iterdir()))
        self.assertIn('startplasma-wayland', self.output.getvalue())


if __name__ == '__main__':
    unittest.main()
