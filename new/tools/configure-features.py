#!/usr/bin/env python3
"""Persist the selected desktop features without replacing unrelated settings."""
import argparse
import json
import os
from pathlib import Path

FEATURES = ('terminals', 'fastfetch', 'shortcuts', 'quicksettings', 'clipboard', 'prescript')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--features', default=','.join(FEATURES))
    parser.add_argument('--restore', action='store_true')
    args = parser.parse_args()
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'index/features.json'
    state = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'index'
    original = state / 'features-before-index.json'
    absent = state / 'features-before-index.absent'
    if args.restore:
        if original.exists():
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_bytes(original.read_bytes())
        elif absent.exists():
            config.unlink(missing_ok=True)
        original.unlink(missing_ok=True)
        absent.unlink(missing_ok=True)
        return
    selected = set(filter(None, args.features.split(',')))
    unknown = selected - set(FEATURES)
    if unknown:
        parser.error('Unknown desktop feature: ' + ', '.join(sorted(unknown)))
    if 'clipboard' in selected:
        selected.add('shortcuts')  # clipboard's picker is opened by Win+V
    state.mkdir(parents=True, exist_ok=True)
    if not original.exists() and not absent.exists():
        if config.exists():
            original.write_bytes(config.read_bytes())
        else:
            absent.touch()
    config.parent.mkdir(parents=True, exist_ok=True)
    temp = config.with_suffix('.json.tmp')
    temp.write_text(json.dumps({name: name in selected for name in FEATURES}, indent=2) + '\n')
    temp.replace(config)


if __name__ == '__main__':
    main()
