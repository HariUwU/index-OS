#!/usr/bin/env python3
"""Run read-only Bluetooth probes against absent hardware and a hung backend."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--shell-dir', type=Path, default=Path(__file__).resolve().parents[1] / 'quickshell')
args = parser.parse_args()
commands = []
for name in ('Bar.qml', 'BluetoothMenu.qml', 'DeviceWatch.qml', 'QuickSettings.qml', 'Settings.qml', 'SettingsPanel.qml'):
    for line in (args.shell_dir / name).read_text().splitlines():
        if 'command:' in line and 'bluetoothctl' in line:
            commands.append((name, json.loads(re.search(r'command:\s*(\[.*\])', line).group(1))[2]))
with tempfile.TemporaryDirectory(prefix='index-polling-test-') as directory:
    temp = Path(directory)
    for name, command in commands:
        # This path is deliberately absent, regardless of the test host hardware.
        command = command.replace('/sys/class/bluetooth', str(temp / 'absent'))
        result = subprocess.run(['sh', '-c', command], capture_output=True, timeout=2)
        assert result.returncode == 0 and not result.stdout, (name, result)
    (temp / 'adapter').mkdir()
    backend = temp / 'bluetoothctl'
    backend.write_text('#!/bin/sh\nsleep 20\n')
    backend.chmod(0o755)
    command = next(cmd for name, cmd in commands if name == 'QuickSettings.qml')
    command = command.replace('/sys/class/bluetooth', str(temp / 'adapter'))
    start = time.monotonic()
    result = subprocess.run(['sh', '-c', command], capture_output=True, timeout=8,
                            env={**os.environ, 'PATH': directory + ':' + os.environ['PATH']})
    elapsed = time.monotonic() - start
    assert result.returncode == 0 and result.stdout == b'0|0|', (result, elapsed)
    assert elapsed < 8, elapsed
    watch_command = next(cmd for name, cmd in commands if name == 'DeviceWatch.qml')
    watch_command = watch_command.replace('/sys/class/bluetooth', str(temp / 'adapter'))
    result = subprocess.run(['sh', '-c', watch_command], capture_output=True, timeout=5,
                            env={**os.environ, 'PATH': directory + ':' + os.environ['PATH']})
    assert result.returncode == 0 and result.stdout == b'INDEX_BT_UNAVAILABLE', result
print(f'PASS: {len(commands)} absent-hardware probes; hung Bluetooth backend exits in {elapsed:.1f}s')
