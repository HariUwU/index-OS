#!/usr/bin/env python3
"""Exercise first-login registration races without a running KDE session."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

DBUS = types.SimpleNamespace(DBusException=type('DBusException', (Exception,), {}),
                            Array=lambda values, **kw: list(values))
spec = importlib.util.spec_from_file_location('shortcuts',
    Path(__file__).resolve().parents[1] / 'bridge/configure-shortcuts.py')
shortcuts = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, dbus=DBUS):
    spec.loader.exec_module(shortcuts)


class StartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=self.temp.name)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.keys = {'Walk Through Windows': [0x09000001, shortcuts.META_TAB, 1234],
                     'Walk Through Windows (Reverse)': [5678, shortcuts.META_TAB],
                     'Overview': [shortcuts.META_W]}
        self.accel = Mock()
        self.accel.allActionsForComponent.return_value = [
            ['kwin', name] for name in self.keys]
        self.accel.shortcut.side_effect = lambda action: self.keys[action[1]][:]
        self.accel.setForeignShortcut.side_effect = lambda action, keys: self.keys.update({action[1]: keys})
        DBUS.SessionBus = Mock()
        DBUS.Interface = Mock(return_value=self.accel)

    def test_cold_registration_has_no_partial_writes(self):
        self.accel.allActionsForComponent.return_value = []
        with self.assertRaises(RuntimeError):
            shortcuts.configure()
        self.accel.unregister.assert_not_called()
        self.accel.setForeignShortcut.assert_not_called()

    def test_move_only_conflicting_key_preserving_other_bindings(self):
        shortcuts.configure()
        self.assertEqual(self.keys['Walk Through Windows'], [0x09000001, 1234])
        self.assertEqual(self.keys['Walk Through Windows (Reverse)'], [5678])
        self.assertEqual(self.keys['Overview'], [shortcuts.META_W, shortcuts.META_TAB])
        shortcuts.configure()
        self.assertEqual(self.keys['Overview'].count(shortcuts.META_TAB), 1)

    def test_disabled_features_stay_disabled_at_login(self):
        folder = Path(self.temp.name) / 'index'
        folder.mkdir()
        (folder / 'features.json').write_text(json.dumps({'shortcuts': False}))
        self.keys['Overview'].append(shortcuts.META_TAB)
        shortcuts.configure()
        self.assertEqual(self.keys['Overview'], [shortcuts.META_W])
        self.accel.unregister.assert_any_call('kwin', 'INDEX Screenshot')

    def test_wait_retries_until_kwin_registers(self):
        registered = self.accel.allActionsForComponent.return_value
        self.accel.allActionsForComponent.side_effect = [[], registered]
        with patch.object(shortcuts.time, 'sleep') as sleep:
            shortcuts.configure_when_ready(wait=15)
        sleep.assert_called_once_with(0.25)
        self.assertNotIn(shortcuts.META_TAB, self.keys['Walk Through Windows'])

    def test_wait_is_bounded_when_kwin_never_arrives(self):
        self.accel.allActionsForComponent.return_value = []
        with patch.object(shortcuts.time, 'monotonic', side_effect=[0, 0, 15]), \
             patch.object(shortcuts.time, 'sleep') as sleep:
            with self.assertRaises(RuntimeError):
                shortcuts.configure_when_ready(wait=15)
        sleep.assert_called_once_with(0.25)


if __name__ == '__main__':
    unittest.main()
