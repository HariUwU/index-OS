#!/usr/bin/env python3
"""Isolated intro regression tests; ffprobe and privileged installs are mocked.

Run: python3 new/tools/test-index-intro.py
"""
from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name('index-intro.py')


class IntroTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='index-intro-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        # Keep automatic recursive cleanup inside the selected temporary root.
        self.assertTrue(self.root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.data = self.root / 'data with spaces'
        self.state = self.data / 'index/intro'
        self.login = self.root / 'mock-system/index-greeter'
        self.user = self.data / 'plasma/look-and-feel/org.index.desktop/contents/lockscreen'
        self.write(self.login / 'greeter.qml', '// installed greeter')
        self.write(self.user / 'LockScreen.qml', '// installed locker')
        (self.login / 'assets').mkdir()
        (self.user / 'assets').mkdir()
        self.namespace = runpy.run_path(str(SCRIPT), run_name='intro_test_module')
        self.globals = self.namespace['main'].__globals__
        self.globals['LOGIN_TARGET'] = self.login
        self.env = mock.patch.dict(os.environ, {'XDG_DATA_HOME': str(self.data), 'SUDO_ASKPASS': ''})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.executable = mock.patch('os.access', return_value=True)
        self.executable.start()
        self.addCleanup(self.executable.stop)
        self.commands = []
        self.command_options = []
        self.on_authorize = lambda: None
        self.probe_valid = True

    @staticmethod
    def write(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def video(self, name, content):
        path = self.root / name
        path.write_bytes(content)
        return path

    def legacy(self, enabled=True, custom=True, video=True):
        self.write(self.state / 'settings.json', json.dumps({'enabled': enabled, 'custom': custom}))
        if video:
            (self.state / 'video').write_bytes(b'legacy video')

    def tree(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes()
                for p in self.root.rglob('*') if p.is_file()}

    def choice(self, scope):
        return json.loads((self.state / scope / 'settings.json').read_text())

    def command(self, command, **kwargs):
        self.commands.append(list(map(str, command)))
        self.command_options.append(kwargs)
        if command[0] == 'ffprobe':
            return subprocess.CompletedProcess(command, 0 if self.probe_valid else 1,
                                               'video\n' if self.probe_valid else '', '')
        self.assertEqual(command[0], 'sudo', 'No real external commands allowed')
        if command == ['sudo', '-A', '-v']:
            self.on_authorize()
            return subprocess.CompletedProcess(command, 0)
        install = command.index('install')
        self.assertEqual(command[install + 1:install + 3], ['-m', '644'])
        source, target = map(Path, command[-2:])
        self.assertTrue(target.resolve().is_relative_to(self.login.resolve()))
        shutil.copyfile(source, target)
        return subprocess.CompletedProcess(command, 0)

    def run_intro(self, *args):
        output = io.StringIO()
        self.stderr = io.StringIO()
        with mock.patch.object(sys, 'argv', [str(SCRIPT), *map(str, args)]), \
                mock.patch('shutil.which', return_value='/mock/ffprobe'), \
                mock.patch('subprocess.run', side_effect=self.command), \
                redirect_stdout(output), redirect_stderr(self.stderr):
            self.namespace['main']()
        return output.getvalue()

    def test_scopes_keep_separate_choices_and_video_bytes(self):
        self.run_intro('--scope', 'user', '--video', self.video('user video.mp4', b'user video'))
        self.run_intro('--scope', 'login', '--video', self.video('login video.mp4', b'login video'))
        self.run_intro('--scope', 'login', '--disable')
        self.run_intro('--scope', 'user', '--apply')
        self.assertEqual(self.choice('user'), {'enabled': True, 'custom': True})
        self.assertEqual(self.choice('login'), {'enabled': False, 'custom': True, 'frequency': 'boot'})
        self.assertEqual((self.state / 'user/video').read_bytes(), b'user video')
        self.assertEqual((self.state / 'login/video').read_bytes(), b'login video')
        self.assertEqual((self.user / 'assets/intro-user.mp4').read_bytes(), b'user video')
        self.assertEqual((self.login / 'assets/intro-user.mp4').read_bytes(), b'login video')

    def test_older_locker_without_assets_directory_accepts_custom_video(self):
        (self.user / 'assets').rmdir()
        self.run_intro('--scope', 'user', '--video', self.video('custom.mp4', b'custom video'))
        self.assertEqual((self.user / 'assets/intro-user.mp4').read_bytes(), b'custom video')

    def test_legacy_custom_choice_migrates_to_both_without_aliasing(self):
        self.legacy()
        original = (self.state / 'settings.json').read_bytes()
        self.run_intro('--scope', 'user', '--disable')
        self.assertEqual(self.choice('user'), {'enabled': False, 'custom': True})
        self.assertEqual(self.choice('login'), {'enabled': True, 'custom': True, 'frequency': 'boot'})
        for scope in ('user', 'login'):
            self.assertEqual((self.state / scope / 'video').read_bytes(), b'legacy video')
        self.run_intro('--scope', 'user', '--video', self.video('replacement.mp4', b'replacement'))
        self.assertEqual((self.state / 'login/video').read_bytes(), b'legacy video')
        self.assertEqual((self.state / 'video').read_bytes(), b'legacy video')
        self.assertEqual((self.state / 'settings.json').read_bytes(), original)
        self.run_intro('--scope', 'login', '--apply')
        self.assertIn('enabled: true', (self.login / 'IntroConfig.qml').read_text())

    def test_existing_scoped_choice_wins_over_legacy_migration(self):
        self.legacy()
        self.write(self.state / 'user/settings.json', '{"enabled": false, "custom": false}')
        self.run_intro('--scope', 'login', '--apply')
        self.assertEqual(self.choice('user'), {'enabled': False, 'custom': False})
        self.assertEqual(self.choice('login'), {'enabled': True, 'custom': True, 'frequency': 'boot'})

    def test_failed_replacement_keeps_migrated_legacy_choice_and_video(self):
        self.legacy(enabled=False)
        video = self.video('replacement.mp4', b'replacement')
        cache = self.globals['cache_video']

        def fail_new_video(source, target):
            if source == video:
                raise OSError('new video copy failed')
            cache(source, target)

        with mock.patch.dict(self.globals, {'cache_video': fail_new_video}):
            with self.assertRaisesRegex(OSError, 'new video copy failed'):
                self.run_intro('--scope', 'user', '--video', video)
        for scope in ('user', 'login'):
            expected = {'enabled': False, 'custom': True}
            if scope == 'login':
                expected['frequency'] = 'boot'
            self.assertEqual(self.choice(scope), expected)
            self.assertEqual((self.state / scope / 'video').read_bytes(), b'legacy video')

    def test_unrelated_malformed_scope_does_not_block_selected_scope(self):
        self.write(self.state / 'user/settings.json', '{"enabled": true, "custom": false}')
        self.write(self.state / 'login/settings.json', '{broken unrelated scope')
        self.run_intro('--scope', 'user', '--disable')
        self.assertEqual(self.choice('user'), {'enabled': False, 'custom': False})
        self.assertEqual((self.state / 'login/settings.json').read_text(), '{broken unrelated scope')

    def test_both_video_selection_creates_independent_caches(self):
        self.run_intro('--video', self.video('both.mp4', b'both scopes'))
        self.run_intro('--scope', 'user', '--video', self.video('user-new.mp4', b'user only'))
        self.assertEqual((self.state / 'user/video').read_bytes(), b'user only')
        self.assertEqual((self.state / 'login/video').read_bytes(), b'both scopes')

    def test_invalid_new_video_does_not_migrate_or_change_legacy_state(self):
        self.legacy()
        video = self.video('invalid.mp4', b'not video')
        before = self.tree()
        self.probe_valid = False
        with self.assertRaises(SystemExit):
            self.run_intro('--video', video)
        self.assertEqual(self.tree(), before)

    def test_enabling_both_preflights_all_scopes_without_partial_writes(self):
        self.write(self.state / 'user/settings.json', '{"enabled": false, "custom": false}')
        self.write(self.state / 'login/settings.json', '{"enabled": false, "custom": true}')
        before = self.tree()
        with self.assertRaises(SystemExit):
            self.run_intro('--enable')
        self.assertEqual(self.tree(), before)

    def test_legacy_disabled_missing_video_migrates_and_applies(self):
        self.legacy(enabled=False, video=False)
        self.run_intro('--apply')
        for scope in ('user', 'login'):
            expected = {'enabled': False, 'custom': True}
            if scope == 'login':
                expected['frequency'] = 'boot'
            self.assertEqual(self.choice(scope), expected)
        self.assertIn('enabled: false', (self.login / 'IntroConfig.qml').read_text())
        self.assertIn('enabled: false', (self.user / 'IntroConfig.qml').read_text())

    def test_disable_missing_custom_succeeds_but_enable_rejects_without_changes(self):
        self.legacy(video=False)
        self.run_intro('--disable')
        before = self.tree()
        self.run_intro('--apply')
        self.assertEqual(self.tree(), before)
        with self.assertRaises(SystemExit) as error:
            self.run_intro('--scope', 'user', '--enable')
        self.assertEqual(error.exception.code, 2)
        self.assertEqual(self.tree(), before)

    def test_check_video_ignores_malformed_legacy_and_scoped_config(self):
        self.write(self.state / 'settings.json', '{broken legacy')
        self.write(self.state / 'user/settings.json', 'null')
        video = self.video('validate.mp4', b'video fixture')
        before = self.tree()
        self.assertIn('Video is readable', self.run_intro('--check-video', video))
        self.assertEqual(self.tree(), before)
        self.assertEqual([c[0] for c in self.commands], ['ffprobe'])

    def test_check_video_never_creates_state_and_rejection_is_read_only(self):
        video = self.video('validate.mp4', b'video fixture')
        before = self.tree()
        self.run_intro('--check-video', video)
        self.assertFalse(self.state.exists())
        self.probe_valid = False
        with self.assertRaises(SystemExit):
            self.run_intro('--check-video', video)
        self.assertEqual(self.tree(), before)

    def test_status_names_scopes_without_migrating(self):
        self.legacy(enabled=False)
        before = self.tree()
        status = json.loads(self.run_intro('--status'))
        self.assertEqual(set(status), {'user', 'login'})
        self.assertEqual(status['user'], {'enabled': False, 'custom': True})
        self.assertEqual(status['login'], dict(status['user'], frequency='boot'))
        self.assertEqual(set(json.loads(self.run_intro('--scope', 'login', '--status'))), {'login'})
        self.assertEqual(self.tree(), before)
        self.assertFalse(self.commands)

    def test_gui_status_adds_installed_without_writes_or_authorization(self):
        self.legacy(enabled=False)
        before = self.tree()
        status = json.loads(self.run_intro('--gui', '--status'))
        self.assertEqual(status, {'user': {'enabled': False, 'custom': True, 'installed': True, 'available': True},
                                  'login': {'enabled': False, 'custom': True, 'installed': True,
                                            'frequency': 'boot', 'available': True}})
        self.assertEqual(self.tree(), before)
        self.assertFalse((self.state / 'user').exists())
        self.assertFalse((self.state / 'login').exists())
        self.assertFalse(self.commands)

    def test_gui_status_detects_native_or_look_and_feel_locker_and_exact_login_file(self):
        native = self.data / 'plasma/shells/org.index.desktop/contents/lockscreen'
        (self.user / 'LockScreen.qml').unlink()
        (self.login / 'greeter.qml').unlink()
        # The wrong screen file must not count as an installed target.
        self.write(self.user / 'greeter.qml', '// not a locker')
        self.write(self.login / 'LockScreen.qml', '// not a greeter')
        before = self.tree()
        status = json.loads(self.run_intro('--gui', '--status'))
        self.assertEqual(status, {'user': {'enabled': True, 'custom': False, 'installed': False, 'available': False},
                                  'login': {'enabled': True, 'custom': False, 'installed': False,
                                            'frequency': 'boot', 'available': False}})
        self.assertEqual(self.tree(), before)
        self.assertFalse(self.state.exists())
        self.write(native / 'LockScreen.qml', '// native locker')
        self.assertEqual(json.loads(self.run_intro('--gui', '--scope', 'user', '--status')),
                         {'user': {'enabled': True, 'custom': False, 'installed': True, 'available': False}})
        self.assertFalse(self.commands)

    def test_gui_missing_targets_reject_all_mutations_before_writes(self):
        self.legacy()
        video = self.video('new.mp4', b'new video')
        for scope, marker in (('user', self.user / 'LockScreen.qml'),
                              ('login', self.login / 'greeter.qml')):
            contents = marker.read_bytes()
            marker.unlink()
            for action in (('--video', video), ('--enable',), ('--disable',), ('--default',)):
                for selected in (scope, 'both'):
                    with self.subTest(scope=selected, missing=scope, action=action):
                        self.commands.clear()
                        before = self.tree()
                        with self.assertRaises(SystemExit) as error:
                            self.run_intro('--gui', '--scope', selected, *action)
                        self.assertEqual(error.exception.code, 2)
                        self.assertIn(f'INDEX {scope} screen is not installed', self.stderr.getvalue())
                        self.assertEqual(self.tree(), before)
                        self.assertFalse((self.state / 'user').exists())
                        self.assertFalse((self.state / 'login').exists())
                        self.assertFalse(any(c[0] == 'sudo' for c in self.commands))
            marker.write_bytes(contents)

    def test_gui_cancelled_authorization_preserves_fresh_legacy_and_scoped_state(self):
        video = self.video("replacement ' with spaces.mp4", b'replacement')

        def cancel():
            raise subprocess.CalledProcessError(1, ['sudo', '-A', '-v'])

        self.on_authorize = cancel
        for saved in ('fresh', 'legacy', 'scoped'):
            if saved == 'legacy':
                self.legacy(enabled=False)
            elif saved == 'scoped':
                for scope in ('user', 'login'):
                    self.write(self.state / scope / 'settings.json',
                               '{ "enabled": false, "custom": true }\n')
                    (self.state / scope / 'video').write_bytes(scope.encode())
            for action in (('--video', video), ('--enable',), ('--disable',), ('--default',)):
                for selected in ('login', 'both'):
                    with self.subTest(saved=saved, scope=selected, action=action):
                        self.commands.clear()
                        before = self.tree()
                        directories = {p for p in self.root.rglob('*') if p.is_dir()}
                        with self.assertRaises(SystemExit) as error:
                            self.run_intro('--gui', '--scope', selected, *action)
                        self.assertEqual(error.exception.code, 2)
                        self.assertIn('authorization cancelled or failed', self.stderr.getvalue())
                        self.assertEqual(self.tree(), before)
                        self.assertEqual({p for p in self.root.rglob('*') if p.is_dir()}, directories)
                        self.assertEqual([c for c in self.commands if c[0] == 'sudo'],
                                         [['sudo', '-A', '-v']])

    def test_gui_authorizes_before_cache_migration_settings_and_installs(self):
        self.legacy(enabled=False)
        video = self.video("replacement ' with spaces.webm", b'replacement')
        before = self.tree()
        events = []

        def authorize():
            self.assertEqual(self.tree(), before)
            self.assertFalse((self.state / 'user').exists())
            self.assertFalse((self.state / 'login').exists())
            events.append('authorized')

        self.on_authorize = authorize
        cache = self.globals['cache_video']
        save = self.globals['save_choice']

        def cache_after_authorization(*args):
            self.assertIn('authorized', events)
            return cache(*args)

        def save_after_authorization(*args):
            self.assertIn('authorized', events)
            return save(*args)

        with mock.patch.dict(self.globals, {'cache_video': cache_after_authorization,
                                            'save_choice': save_after_authorization}), \
                mock.patch.dict(os.environ, {'SUDO_ASKPASS': '/untrusted/inherited askpass'}):
            self.run_intro('--gui', '--scope', 'login', '--video', video)
            self.assertEqual(os.environ['SUDO_ASKPASS'], '/untrusted/inherited askpass')
        sudo_calls = [(c, options) for c, options in zip(self.commands, self.command_options)
                      if c[0] == 'sudo']
        self.assertEqual(sudo_calls[0][0], ['sudo', '-A', '-v'])
        self.assertEqual(len(sudo_calls), 3)
        for command, options in sudo_calls:
            self.assertEqual(command[:2], ['sudo', '-A'])
            self.assertTrue(options['check'])
            self.assertEqual(options['env']['SUDO_ASKPASS'], str(SCRIPT.resolve().with_name('index-askpass.sh')))
            self.assertFalse(options.get('shell', False))
        self.assertEqual(self.choice('login'), {'enabled': True, 'custom': True, 'frequency': 'boot'})
        self.assertEqual((self.state / 'login/video').read_bytes(), b'replacement')
        self.assertEqual((self.login / 'assets/intro-user.mp4').read_bytes(), b'replacement')

    def test_gui_user_mutation_needs_no_authorization(self):
        self.run_intro('--gui', '--scope', 'user', '--disable')
        self.assertEqual(self.choice('user'), {'enabled': False, 'custom': False})
        self.assertIn('enabled: false', (self.user / 'IntroConfig.qml').read_text())
        self.assertFalse(self.commands)

    def test_gui_missing_askpass_or_kdialog_fails_without_writes(self):
        self.legacy()
        for missing in ('askpass', 'kdialog'):
            with self.subTest(missing=missing):
                before = self.tree()
                with mock.patch('os.access', return_value=missing != 'askpass'), \
                        mock.patch('shutil.which', return_value=None if missing == 'kdialog' else '/mock/kdialog'):
                    # Patch inside run_intro's dependency stub to model missing kdialog.
                    authorize = self.globals['authorize_login']

                    def with_dependencies(parser):
                        with mock.patch('shutil.which', return_value=None if missing == 'kdialog' else '/mock/kdialog'):
                            return authorize(parser)

                    with mock.patch.dict(self.globals, {'authorize_login': with_dependencies}):
                        with self.assertRaises(SystemExit):
                            self.run_intro('--gui', '--scope', 'login', '--disable')
                self.assertIn('index-askpass.sh' if missing == 'askpass' else 'kdialog', self.stderr.getvalue())
                self.assertEqual(self.tree(), before)
                self.assertFalse(self.commands)

    def test_both_apply_uses_each_saved_choice_and_video(self):
        self.run_intro('--scope', 'user', '--video', self.video('user.mp4', b'user'))
        self.run_intro('--scope', 'login', '--video', self.video('login.mp4', b'login'))
        self.run_intro('--scope', 'login', '--disable')
        self.run_intro('--apply')
        self.assertIn('enabled: true', (self.user / 'IntroConfig.qml').read_text())
        self.assertIn('enabled: false', (self.login / 'IntroConfig.qml').read_text())
        self.assertEqual((self.user / 'assets/intro-user.mp4').read_bytes(), b'user')
        self.assertEqual((self.login / 'assets/intro-user.mp4').read_bytes(), b'login')

    def test_fresh_install_without_media_skips_video_immediately(self):
        self.run_intro('--apply')
        for target in (self.user, self.login):
            qml = (target / 'IntroConfig.qml').read_text()
            self.assertIn('enabled: false', qml)
            self.assertIn('property url videoSource: ""', qml)
        status = json.loads(self.run_intro('--gui', '--status'))
        self.assertFalse(status['user']['available'])
        self.assertFalse(status['login']['available'])

    def test_optional_asset_video_is_enabled_only_on_targets_that_have_it(self):
        (self.user / 'assets/intro.mp4').write_bytes(b'user supplied')
        self.run_intro('--apply')
        self.assertIn('enabled: true', (self.user / 'IntroConfig.qml').read_text())
        self.assertIn('enabled: false', (self.login / 'IntroConfig.qml').read_text())
        status = json.loads(self.run_intro('--gui', '--status'))
        self.assertTrue(status['user']['available'])
        self.assertFalse(status['login']['available'])

    def test_reset_without_asset_skips_intro_and_keeps_custom_cache(self):
        self.run_intro('--scope', 'user', '--video', self.video('own.mp4', b'custom'))
        self.run_intro('--scope', 'user', '--default')
        self.assertEqual((self.state / 'user/video').read_bytes(), b'custom')
        self.assertEqual(self.choice('user'), {'enabled': True, 'custom': False})
        self.assertIn('enabled: false', (self.user / 'IntroConfig.qml').read_text())

    def test_scoped_default_does_not_reset_other_scope(self):
        self.legacy()
        self.run_intro('--scope', 'user', '--default')
        self.assertEqual(self.choice('user'), {'enabled': True, 'custom': False})
        self.assertEqual(self.choice('login'), {'enabled': True, 'custom': True, 'frequency': 'boot'})

    def test_greeter_apply_uses_mocked_privileged_fixed_destinations(self):
        with mock.patch.dict(os.environ, {'SUDO_ASKPASS': '/mock/askpass'}):
            self.run_intro('--scope', 'login', '--video', self.video("name ' with spaces.webm", b'custom'))
        installs = [c for c in self.commands if c[0] == 'sudo']
        self.assertEqual(len(installs), 2)
        self.assertTrue(all(c[:2] == ['sudo', '-A'] for c in installs))
        self.assertEqual(Path(installs[0][-2]), self.state / 'login/video')
        self.assertEqual(Path(installs[0][-1]), self.login / 'assets/intro-user.mp4')
        qml = (self.login / 'IntroConfig.qml').read_text()
        self.assertIn('assets/intro-user.mp4', qml)
        self.assertNotIn('name ', qml)
        self.assertFalse((self.user / 'IntroConfig.qml').exists())

    def test_frequency_rejects_ambiguous_scopes_before_any_work(self):
        self.legacy()
        before = self.tree()
        for scope_args in ((), ('--scope', 'both'), ('--scope', 'user')):
            with self.subTest(scope=scope_args):
                with self.assertRaises(SystemExit) as error:
                    self.run_intro('--gui', *scope_args, '--frequency', 'always',
                                   '--video', self.root / 'does-not-exist.mp4')
                self.assertEqual(error.exception.code, 2)
                self.assertIn('--frequency requires --scope login', self.stderr.getvalue())
                self.assertEqual(self.tree(), before)
                self.assertFalse(self.commands)

    def test_invalid_frequency_and_read_only_combinations_do_not_change_state(self):
        before = self.tree()
        for args in (('--frequency', 'never'), ('--frequency', 'boot', '--status'),
                     ('--frequency', 'always', '--check-video', self.root / 'missing.mp4')):
            with self.subTest(args=args):
                with self.assertRaises(SystemExit):
                    self.run_intro('--scope', 'login', *args)
                self.assertEqual(self.tree(), before)
                self.assertFalse(self.commands)

    def test_login_default_and_old_scoped_choices_are_boot_without_status_writes(self):
        for saved in (None, {'enabled': False, 'custom': True}):
            if saved is not None:
                self.write(self.state / 'login/settings.json', json.dumps(saved))
            before = self.tree()
            status = json.loads(self.run_intro('--scope', 'login', '--status'))['login']
            self.assertEqual(status, dict(saved or {'enabled': True, 'custom': False}, frequency='boot'))
            self.assertEqual(self.tree(), before)
        self.run_intro('--scope', 'login', '--apply')
        self.assertEqual(self.choice('login')['frequency'], 'boot')
        self.assertIn('oncePerBoot: true', (self.login / 'IntroConfig.qml').read_text())

    def test_frequency_survives_video_toggle_default_and_both_apply(self):
        for frequency in ('always', 'boot'):
            with self.subTest(frequency=frequency):
                self.run_intro('--scope', 'login', '--frequency', frequency)
                for action in (('--video', self.video('frequency.mp4', b'custom')),
                               ('--disable',), ('--enable',), ('--default',), ('--apply',)):
                    self.run_intro('--scope', 'login', *action)
                    self.assertEqual(self.choice('login')['frequency'], frequency)
                    qml = (self.login / 'IntroConfig.qml').read_text()
                    self.assertIn('oncePerBoot: ' + str(frequency == 'boot').lower(), qml)
                self.run_intro('--video', self.video('both-frequency.mp4', b'both'))
                self.run_intro('--apply')
                self.assertEqual(self.choice('login'),
                                 {'enabled': True, 'custom': True, 'frequency': frequency})
                self.assertEqual(self.choice('user'), {'enabled': True, 'custom': True})
                self.assertNotIn('oncePerBoot', (self.user / 'IntroConfig.qml').read_text())

    def test_legacy_frequency_migrates_only_to_login_and_scoped_value_wins(self):
        self.legacy()
        self.write(self.state / 'settings.json',
                   '{"enabled": true, "custom": true, "frequency": "always"}')
        before = (self.state / 'settings.json').read_bytes()
        self.run_intro('--scope', 'user', '--apply')
        self.assertEqual(self.choice('login')['frequency'], 'always')
        self.assertNotIn('frequency', self.choice('user'))
        self.assertEqual((self.state / 'settings.json').read_bytes(), before)
        self.run_intro('--scope', 'login', '--frequency', 'boot')
        self.run_intro('--scope', 'login', '--apply')
        self.assertEqual(self.choice('login')['frequency'], 'boot')

    def test_frequency_change_preserves_disabled_video_and_other_scope(self):
        self.run_intro('--video', self.video('keep.mp4', b'keep me'))
        self.run_intro('--scope', 'login', '--disable')
        user_before = (self.state / 'user/settings.json').read_bytes()
        self.run_intro('--scope', 'login', '--frequency', 'always')
        self.assertEqual(self.choice('login'),
                         {'enabled': False, 'custom': True, 'frequency': 'always'})
        self.assertEqual((self.state / 'login/video').read_bytes(), b'keep me')
        self.assertEqual((self.state / 'user/settings.json').read_bytes(), user_before)

    def test_scoped_frequency_wins_during_other_scope_legacy_migration(self):
        self.legacy(enabled=False)
        self.write(self.state / 'login/settings.json',
                   '{"enabled": true, "custom": false, "frequency": "always"}')
        login_before = (self.state / 'login/settings.json').read_bytes()
        self.run_intro('--scope', 'user', '--apply')
        self.assertEqual((self.state / 'login/settings.json').read_bytes(), login_before)
        self.run_intro('--apply')
        self.assertEqual(self.choice('login')['frequency'], 'always')
        self.assertIn('oncePerBoot: false', (self.login / 'IntroConfig.qml').read_text())

    def test_video_and_frequency_can_be_selected_together(self):
        self.run_intro('--scope', 'login', '--frequency', 'always', '--video',
                       self.video('custom frequency.webm', b'custom frequency'))
        self.assertEqual(self.choice('login'),
                         {'enabled': True, 'custom': True, 'frequency': 'always'})
        qml = (self.login / 'IntroConfig.qml').read_text()
        self.assertIn('oncePerBoot: false', qml)
        self.assertIn('assets/intro-user.mp4', qml)
        self.assertFalse((self.state / 'user').exists())

    def test_cancelled_frequency_change_preserves_state_and_installed_config(self):
        self.run_intro('--scope', 'login', '--frequency', 'always')
        before = self.tree()

        def cancel():
            raise subprocess.CalledProcessError(1, ['sudo', '-A', '-v'])

        self.on_authorize = cancel
        with self.assertRaises(SystemExit):
            self.run_intro('--gui', '--scope', 'login', '--frequency', 'boot')
        self.assertEqual(self.tree(), before)

    def test_invalid_saved_login_frequency_rejects_without_writes(self):
        self.write(self.state / 'login/settings.json',
                   '{"enabled": true, "custom": false, "frequency": "invalid"}')
        before = self.tree()
        with self.assertRaisesRegex(ValueError, 'Invalid login intro frequency'):
            self.run_intro('--scope', 'login', '--apply')
        self.assertEqual(self.tree(), before)
        self.assertFalse(self.commands)


if __name__ == '__main__':
    unittest.main()
