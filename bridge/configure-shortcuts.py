#!/usr/bin/env python3
"""Give Win+Tab to native Overview without disturbing Alt+Tab or other keys."""
import dbus
import argparse
import json
import os
import time
from pathlib import Path

META_TAB = 0x11000001
META_W = 0x10000057


def configure(disable=False):
    bus = dbus.SessionBus()
    accel = dbus.Interface(bus.get_object('org.kde.kglobalaccel', '/kglobalaccel'),
                           'org.kde.KGlobalAccel')
    registered = {str(action[1]) for action in
                  accel.allActionsForComponent(['kwin', '', 'KWin', ''])}
    if not {'Overview', 'Walk Through Windows'}.issubset(registered):
        raise RuntimeError('KWin shortcuts are not registered yet')

    def action(name):
        return dbus.Array(['kwin', name, 'KWin', name], signature='s')

    # Remove the obsolete INDEX forwarding action. A native action avoids a
    # second D-Bus invocation while KWin is processing the original key.
    accel.unregister('kwin', 'INDEX Task View')
    selected = {}
    try:
        selected = json.loads((Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'index/features.json').read_text())
        if not isinstance(selected, dict):
            selected = {}
    except (OSError, ValueError):
        pass
    disable = disable or selected.get('shortcuts') is False
    for name, feature in [('INDEX Clipboard', 'clipboard'), ('INDEX Quick Settings', 'quicksettings'),
                          ('INDEX Screenshot', 'shortcuts'), ('INDEX Task Manager', 'shortcuts')]:
        if disable or selected.get(feature) is False:
            accel.unregister('kwin', name)
    if disable:
        keys = [key for key in accel.shortcut(action('Overview')) if int(key) != META_TAB]
        accel.setForeignShortcut(action('Overview'), dbus.Array(keys, signature='i'))
        print('Optional Windows shortcuts disabled; native Alt+Tab is unchanged')
        return
    # Some KDE configurations bind Meta+Tab to window cycling as well as
    # Alt+Tab. Remove just Meta+Tab, including its reverse counterpart.
    for name in ['Walk Through Windows', 'Walk Through Windows (Reverse)']:
        keys = list(accel.shortcut(action(name)))
        keep = [key for key in keys if int(key) != META_TAB]
        if keep != keys:
            accel.setForeignShortcut(action(name), dbus.Array(keep, signature='i'))
    keys = list(accel.shortcut(action('Overview')))
    for key in [META_TAB, META_W]:
        if key not in keys:
            keys.append(key)
    accel.setForeignShortcut(action('Overview'), dbus.Array(keys, signature='i'))
    print('Win+Tab: native Overview; existing Alt+Tab shortcuts preserved')


def configure_when_ready(disable=False, wait=0):
    deadline = time.monotonic() + max(0, wait)
    while True:
        try:
            configure(disable)
            break
        except (dbus.DBusException, RuntimeError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.25)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--disable', action='store_true')
    parser.add_argument('--wait', type=float, default=0,
                        help='Wait this many seconds for KWin at session startup')
    args = parser.parse_args()
    configure_when_ready(args.disable, args.wait)
