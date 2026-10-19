#!/usr/bin/env python3
"""Exercise console setup orchestration with stub commands and temporary config.

Run: python3 -B tools/test-setup-prerequisites.py
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
        self.assertEqual(self.commands[1], ['bash', str(setup.SRC / 'install-desktop.sh'),
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

    def test_media_paths_respect_xdg_and_overlay_priority(self):
        source = self.root / 'source'
        overlay = self.root / 'personal/index/assets'
        (source / 'assets/sounds').mkdir(parents=True)
        (source / 'assets/intro.mp4').write_bytes(b'source video')
        (source / 'assets/sounds/bg.mp3').write_bytes(b'source audio')
        overlay.mkdir(parents=True)
        (overlay / 'intro.mp4').write_bytes(b'personal video')
        with mock.patch.object(setup, 'SRC', source), \
                mock.patch.dict(os.environ, XDG_DATA_HOME=str(self.root / 'personal')):
            lines = setup.optional_media_lines({'desktop', 'intro'})
        self.assertIn(str(overlay / 'intro.mp4'), lines)
        self.assertIn(str(overlay / 'sounds/bg.mp3'), lines)
        self.assertIn('Found: ' + str(overlay / 'intro.mp4'), lines)
        self.assertIn('Found: ' + str(source / 'assets/sounds/bg.mp3'), lines)
        self.assertNotIn('Found: ' + str(source / 'assets/intro.mp4'), lines)

    def test_missing_media_is_optional_and_inspection_writes_nothing(self):
        with mock.patch.object(setup, 'SRC', self.root / 'source'), \
                mock.patch.dict(os.environ, XDG_DATA_HOME=str(self.root / 'personal')):
            lines = setup.optional_media_lines({'desktop'})
        self.assertEqual(lines.count('Not supplied (optional)'), 2)
        self.assertIn('Intro playback is off because the Intro video component is not selected.', lines)
        self.assertFalse(list(self.root.iterdir()))

    def test_cancel_media_stops_before_packages_or_confirmation(self):
        menu = SimpleNamespace(prepare_media=mock.Mock(return_value=False),
                               confirm_install=mock.Mock())
        with mock.patch.dict(sys.modules, setup_menu=menu), \
                mock.patch.object(sys.stdin, 'isatty', return_value=True), \
                mock.patch.object(self.output, 'isatty', return_value=True), \
                mock.patch.object(sys, 'argv', ['setup.py', '--components', 'desktop']), \
                mock.patch.object(setup, 'run') as run, redirect_stdout(self.output):
            setup.main()
        menu.prepare_media.assert_called_once()
        menu.confirm_install.assert_not_called()
        run.assert_not_called()
        self.assertIn('Cancelled; nothing changed.', self.output.getvalue())

    def test_continue_media_refreshes_status_before_final_review(self):
        def prepare(describe):
            self.assertIn('Not supplied (optional)', describe())
            media = self.root / 'data/index/assets'
            (media / 'sounds').mkdir(parents=True)
            (media / 'intro.mp4').write_bytes(b'personal video')
            (media / 'sounds/bg.mp3').write_bytes(b'personal music')
            return True

        menu = SimpleNamespace(prepare_media=mock.Mock(side_effect=prepare),
                               confirm_install=mock.Mock(return_value=False))
        platform = SimpleNamespace(name='posix', geteuid=lambda: 1000,
                                   environ=dict(os.environ, XDG_CONFIG_HOME=str(self.root / 'config'),
                                                XDG_DATA_HOME=str(self.root / 'data')))
        with mock.patch.dict(sys.modules, setup_menu=menu), \
                mock.patch.object(setup, 'os', platform), \
                mock.patch.object(setup, 'SRC', self.root / 'source'), \
                mock.patch.object(setup.shutil, 'which', return_value='/usr/bin/pacman'), \
                mock.patch.object(sys.stdin, 'isatty', return_value=True), \
                mock.patch.object(self.output, 'isatty', return_value=True), \
                mock.patch.object(sys, 'argv', ['setup.py', '--components', 'desktop,intro']), \
                mock.patch.object(setup, 'run') as run, redirect_stdout(self.output):
            setup.main()
        self.assertIn('Found: ' + str(self.root / 'data/index/assets/intro.mp4'),
                      menu.confirm_install.call_args.args[-1])
        self.assertIn('Found: ' + str(self.root / 'data/index/assets/sounds/bg.mp3'),
                      menu.confirm_install.call_args.args[-1])
        run.assert_not_called()
        self.assertFalse((self.root / 'config').exists())


if __name__ == '__main__':
    unittest.main()
