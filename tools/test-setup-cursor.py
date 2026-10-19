#!/usr/bin/env python3
"""Cursor-step regression tests with a stub build and temporary data directory.

Run: python3 tools/test-setup-cursor.py
Only the cursor branch is executed; no packages, shell commands or desktop writes.
"""
import ast
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SETUP = Path(__file__).with_name('setup.py')


class CursorSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='index-cursor-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data with spaces'
        self.destination = self.data / 'icons/INDEX-Needle'
        self.builds = []
        self.fail_build = False
        # Isolate the actual cursor branch from platform checks and other steps.
        main = next(node for node in ast.parse(SETUP.read_text(encoding='utf-8')).body
                    if isinstance(node, ast.FunctionDef) and node.name == 'main')
        branch = next(node for node in main.body
                      if isinstance(node, ast.If)
                      and ast.dump(node.test) == ast.dump(ast.parse("'cursor' in selected", mode='eval').body))
        self.code = compile(ast.Module(body=[branch], type_ignores=[]), str(SETUP), 'exec')

    def stub_build(self, command):
        self.assertEqual(command[:2], ['bash', self.root / 'source/cursor/index-needle/build.sh'])
        target = Path(command[2])
        self.assertFalse(target.exists(), 'Build output must be fresh')
        self.assertNotEqual(target, self.destination, 'Never build into the installed theme')
        self.assertEqual(target.parent.parent, self.destination.parent)
        self.assertTrue(target.parent.is_dir())
        self.builds.append(target)
        target.mkdir()
        (target / 'index.theme').write_text(f'build {len(self.builds)}', encoding='utf-8')
        if self.fail_build:
            raise subprocess.CalledProcessError(17, command)
        (target / 'cursors').mkdir()
        (target / 'cursors/default').write_bytes(b'stub cursor')

    def run_cursor_step(self):
        namespace = {'selected': {'cursor'}, 'Path': Path, 'os': os,
                     'SRC': self.root / 'source', 'run': self.stub_build}
        with mock.patch.dict(os.environ, {'XDG_DATA_HOME': str(self.data)}), redirect_stdout(io.StringIO()):
            exec(self.code, namespace)

    def contents(self):
        return (self.destination / 'index.theme').read_text(encoding='utf-8')

    def test_first_build_promotes_complete_theme(self):
        self.run_cursor_step()
        self.assertEqual(self.contents(), 'build 1')
        self.assertEqual((self.destination / 'cursors/default').read_bytes(), b'stub cursor')
        self.assertFalse(self.builds[0].exists())

    def test_reruns_preserve_unique_backups(self):
        self.run_cursor_step()
        self.run_cursor_step()
        self.run_cursor_step()
        self.assertEqual(self.contents(), 'build 3')
        self.assertEqual(len(set(path.parent for path in self.builds)), 3)
        for index in (1, 2):
            backups = list(self.builds[index].parent.glob('previous-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / 'index.theme').read_text(encoding='utf-8'), f'build {index}')
            self.assertEqual((backups[0] / 'cursors/default').read_bytes(), b'stub cursor')

    def test_failed_build_preserves_installed_theme(self):
        self.run_cursor_step()
        self.fail_build = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_cursor_step()
        self.assertEqual(self.contents(), 'build 1')
        self.assertTrue((self.destination / 'cursors/default').is_file())
        self.assertFalse(list(self.builds[-1].parent.glob('previous-*')))

    def test_failed_first_build_does_not_install_partial_theme(self):
        self.fail_build = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_cursor_step()
        self.assertFalse(self.destination.exists())

    def test_failed_promotion_restores_previous_theme(self):
        self.run_cursor_step()
        rename = Path.rename

        def fail_promotion(source, target):
            if Path(target) == self.destination and source.name == 'INDEX-Needle':
                raise OSError('promotion refused')
            return rename(source, target)

        with mock.patch.object(Path, 'rename', fail_promotion):
            with self.assertRaisesRegex(OSError, 'promotion refused'):
                self.run_cursor_step()
        self.assertEqual(self.contents(), 'build 1')
        self.assertTrue((self.destination / 'cursors/default').is_file())
        self.assertTrue(self.builds[-1].is_dir(), 'Failed candidate retained for inspection')


if __name__ == '__main__':
    unittest.main()
