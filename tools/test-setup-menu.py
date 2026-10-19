#!/usr/bin/env python3
"""Exercise real installer keystrokes in a disposable Linux pseudo-terminal."""
import os
from pathlib import Path
import runpy
import select
import subprocess
import sys
import tempfile
import time
import unittest

if os.name == 'posix':
    import curses
    import fcntl
    import pty
    import struct
    import termios

TOOLS = Path(__file__).resolve().parent


@unittest.skipUnless(os.name == 'posix', 'Linux terminal required')
class MenuTests(unittest.TestCase):
    def run_terminal(self, command, keys, marker, height=24, width=100, then=None):
        with tempfile.TemporaryDirectory(prefix='index-checklist-') as fixture:
            master, slave = pty.openpty()
            try:
                fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', height, width, 0, 0))
                before = termios.tcgetattr(slave)
                env = dict(os.environ, TERM='xterm-256color', PYTHONDONTWRITEBYTECODE='1',
                           XDG_CONFIG_HOME=fixture + '/config', XDG_DATA_HOME=fixture + '/data',
                           PYTHONPATH=str(TOOLS))
                child = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env)
                output = bytearray()
                pending = [(marker, keys), *(then or [])]
                deadline = time.monotonic() + 10
                try:
                    while time.monotonic() < deadline:
                        ready, _, _ = select.select([master], [], [], 0.1)
                        if ready:
                            output.extend(os.read(master, 65536))
                        if pending and pending[0][0] in output:
                            os.write(master, pending.pop(0)[1])
                        if child.poll() is not None:
                            while select.select([master], [], [], 0)[0]:
                                output.extend(os.read(master, 65536))
                            break
                    else:
                        self.fail('Checklist timed out: ' + output.decode(errors='replace'))
                    self.assertFalse(pending, output)
                    self.assertEqual(child.wait(timeout=1), 0, output.decode(errors='replace'))
                    self.assertEqual(termios.tcgetattr(slave), before, 'Terminal mode was not restored')
                    self.assertFalse(list(Path(fixture).rglob('*')), 'Preview/cancel changed user settings')
                    return output.decode(errors='replace')
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.wait()
            finally:
                os.close(master)
                os.close(slave)

    def test_arrow_space_enter_selects_only_fastfetch(self):
        # Uncheck desktop (and its dependents), intro, and terminal themes.
        output = self.run_terminal([sys.executable, str(TOOLS / 'setup.py'), '--dry-run'],
                                   b' \x1bOB\x1bOB \x1bOB \n', b'THE INDEX / INSTALL')
        plan = output.split('Selected components:')[-1]
        self.assertIn('Dependencies: fastfetch', plan)
        self.assertIn('+ Fastfetch:', plan)
        self.assertNotIn('+ Desktop:', plan)
        self.assertNotIn('+ Intro video:', plan)
        self.assertNotIn('+ Terminal themes:', plan)
        self.assertIn('Preview only; no changes made.', plan)

    def test_escape_cancels_in_small_terminal(self):
        output = self.run_terminal([sys.executable, str(TOOLS / 'setup.py'), '--dry-run'],
                                   b'\x1bOB' * 9 + b'\x1b', b'THE INDEX / INSTALL', height=14, width=60)
        self.assertIn('Cancelled; nothing changed.', output)
        self.assertNotIn('Selected components:', output)

    def test_enter_confirms_review(self):
        code = "from setup_menu import confirm_install; print('CONFIRMED', confirm_install({'fastfetch':'Fastfetch: INDEX logo'}, {'fastfetch'}, ['fastfetch'], 'pacman', False))"
        output = self.run_terminal([sys.executable, '-c', code], b'\n', b'THE INDEX / REVIEW INSTALLATION')
        self.assertIn('CONFIRMED True', output)

    def test_escape_cancels_review(self):
        code = "from setup_menu import confirm_install; print('CONFIRMED', confirm_install({'fastfetch':'Fastfetch: INDEX logo'}, {'fastfetch'}, ['fastfetch'], 'pacman', False))"
        output = self.run_terminal([sys.executable, '-c', code], b'\x1b', b'THE INDEX / REVIEW INSTALLATION')
        self.assertIn('CONFIRMED False', output)

    def test_optional_media_rechecks_and_continues(self):
        code = "from setup_menu import prepare_media; from pathlib import Path; import os; root=Path(os.environ['XDG_DATA_HOME'])/'index/assets'; describe=lambda: ['Intro: '+str(root/'intro.mp4'), 'Music: '+str(root/'sounds/bg.mp3'), 'Both files are optional.']; print('CONTINUE', prepare_media(describe))"
        output = self.run_terminal([sys.executable, '-c', code], b'r\n',
                                   b'THE INDEX / OPTIONAL VIDEO AND MUSIC')
        self.assertIn('intro.mp4', output)
        self.assertIn('bg.mp3', output)
        self.assertIn('CONTINUE True', output)

    def test_optional_media_escape_cancels_in_small_terminal(self):
        code = "from setup_menu import prepare_media; print('CONTINUE', prepare_media(lambda: ['No files supplied.']*30))"
        output = self.run_terminal([sys.executable, '-c', code], b'\x1bOB'*10+b'\x1b',
                                   b'THE INDEX / OPTIONAL VIDEO AND MUSIC', height=14, width=60)
        self.assertIn('CONTINUE False', output)

    def test_real_setup_waits_for_media_then_review_before_changes(self):
        output = self.run_terminal([sys.executable, str(TOOLS / 'setup.py'),
                                    '--components', 'desktop,intro'],
                                   b'r\n', b'THE INDEX / OPTIONAL VIDEO AND MUSIC',
                                   then=[(b'Enter: INSTALL', b'\x1b')])
        self.assertIn('Not supplied (optional)', output)
        self.assertIn('intro.mp4', output)
        self.assertIn('bg.mp3', output)
        self.assertIn('Cancelled; nothing changed.', output)

    def test_dependency_checkboxes_stay_consistent(self):
        from setup_menu import toggle_component
        normalize = runpy.run_path(str(TOOLS / 'setup.py'))['normalize']
        selected = toggle_component(set(), 'clipboard', normalize)
        self.assertEqual(selected, {'desktop', 'shortcuts', 'clipboard'})
        self.assertEqual(toggle_component(selected, 'shortcuts', normalize), {'desktop'})
        self.assertEqual(toggle_component(selected, 'desktop', normalize), set())


if __name__ == '__main__':
    unittest.main()
