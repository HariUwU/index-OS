#!/usr/bin/env python3
"""Keep desktop assets while excluding only videos and login background music."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('prepare',
    Path(__file__).resolve().parents[1] / 'packaging/arch/prepare.py')
prepare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(prepare)


class PackageAssetsTests(unittest.TestCase):
    def test_only_video_and_background_music_are_excluded(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            required = set(prepare.ROOT_FILES)
            required.update('tools/' + name for name in prepare.TOOLS)
            required.update('cursor/index-needle/' + name for name in prepare.CURSOR_FILES)
            required.update('packaging/arch/' + name for name in prepare.PACKAGE_FILES)
            required.update({'bridge/index-kwin-bridge', 'quickshell/qmldir',
                'quickshell/shell.qml', 'kde/aurorae/index/indexrc',
                'kde/look-and-feel/org.index.desktop/contents/defaults',
                'fastfetch/index.txt', 'greeter/run-greeter', prepare.UNIVERSAL_FONT})
            personal = {'assets/intro.mp4', 'assets/sounds/bg.mp3',
                        'greeter/assets/intro.mp4', 'greeter/assets/sounds/bg.mp3'}
            retained = {'assets/Logo.png', 'quickshell/assets/wall.png',
                        'assets/sounds/check.wav', 'assets/sounds/ui/scramble.mp3',
                        'assets/norwester.otf', 'quickshell/lock/assets/DefaultProfile.jpg'}
            for name in required | personal | retained:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fixture')
            packaged = {p.relative_to(root).as_posix() for p in prepare.runtime_files(root)}
            self.assertFalse(packaged & personal)
            self.assertTrue(retained <= packaged)
            self.assertIn(prepare.UNIVERSAL_FONT, packaged)
            self.assertIn('packaging/arch/index-os.svg', packaged)

    def test_real_payload_keeps_original_visuals_sfx_and_universal_font(self):
        files = prepare.runtime_files(prepare.ROOT)
        names = {p.relative_to(prepare.ROOT).as_posix() for p in files}
        self.assertTrue({prepare.UNIVERSAL_FONT, 'assets/Logo.png',
                         'quickshell/assets/wall.png', 'assets/Power.png',
                         'assets/Restart.png', 'assets/sounds/check.wav',
                         'assets/sounds/ui/scramble.mp3'} <= names)
        self.assertFalse([p for p in files if p.suffix.lower() in prepare.PERSONAL_VIDEO
                          or p.name.lower() == 'bg.mp3'])


if __name__ == '__main__':
    unittest.main()
