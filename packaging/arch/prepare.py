#!/usr/bin/env python3
"""Create a checksummed Arch build directory from the reviewed runtime sources."""
import argparse
import gzip
import hashlib
import io
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[2]
ROOT_FILES = ('install.sh', 'install-desktop.sh', 'install-greeter.sh', 'setup.sh',
              'README.md', 'DESKTOP.md', 'LICENSE', 'ATTRIBUTION.md')
DIRECTORIES = ('assets', 'bridge', 'cursor/index-needle/src', 'fastfetch', 'greeter', 'kde',
               'quickshell', 'session', 'wallpaper')
SUFFIXES = {'.qml', '.js', '.json', '.jsonc', '.png', '.jpg', '.jpeg', '.svg', '.mp4', '.mp3',
            '.wav', '.ogg', '.ttf', '.otf', '.colors', '.colorscheme', '.profile', '.toml',
            '.desktop', '.service', '.sh', '.py', '.md', '.txt', '.rc', '.theme'}
TOOLS = ('setup.py', 'setup_menu.py', 'configure-features.py', 'install-extras.sh',
         'index-intro.py', 'index-askpass.sh', 'install-assets.py', 'verify-desktop.sh')
CURSOR_FILES = ('build.sh', 'roles.tsv', 'aliases.tsv', 'index.theme', 'README.md')
PACKAGE_FILES = ('index-setup', 'index-intro', 'index-os.desktop', 'index-os.install',
                 'index-os.svg', 'PKGBUILD.in', 'prepare.py', 'README.md')
SPECIAL_NAMES = {'qmldir', 'run-greeter', 'index-kwin-bridge', 'indexrc', 'defaults'}
PERSONAL_VIDEO = {'.mp4', '.webm', '.mkv', '.mov', '.m4v', '.avi'}
UNIVERSAL_FONT = 'assets/PerfectDOSVGA437-Universal.ttf'


def runtime_files(root):
    files = {root / name for name in ROOT_FILES}
    files.update(root / 'tools' / name for name in TOOLS)
    files.update(root / 'cursor/index-needle' / name for name in CURSOR_FILES)
    files.update(root / 'packaging/arch' / name for name in PACKAGE_FILES)
    for directory in DIRECTORIES:
        for path in (root / directory).rglob('*'):
            if path.is_symlink():
                raise ValueError(f'Unexpected source symlink: {path}')
            if not path.is_file() or any(part in ('__pycache__', '.git', 'build') for part in path.relative_to(root).parts):
                continue
            # Only intro video and login background music are user supplied.
            # Keep the existing artwork, wallpaper, sound effects and fonts.
            if path.suffix.lower() in PERSONAL_VIDEO or path.name.lower() == 'bg.mp3':
                continue
            if path.suffix.lower() in SUFFIXES or path.name in SPECIAL_NAMES:
                files.add(path)
    for path in files:
        if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Missing or invalid runtime file: {path}')
        relative = path.relative_to(root).as_posix()
        if any(ord(char) < 32 for char in relative) or any(len(part.encode('utf-8')) > 255 for part in path.relative_to(root).parts):
            raise ValueError(f'Unsupported runtime filename: {relative}')
    required = {'bridge/index-kwin-bridge', 'quickshell/qmldir', 'quickshell/shell.qml',
                'kde/aurorae/index/indexrc', 'kde/look-and-feel/org.index.desktop/contents/defaults',
                'fastfetch/index.txt', 'greeter/run-greeter', 'assets/PerfectDOSVGA437-Universal.ttf'}
    missing = required - {path.relative_to(root).as_posix() for path in files}
    if missing:
        raise ValueError('Missing runtime files: ' + ', '.join(sorted(missing)))
    return sorted(files, key=lambda path: path.relative_to(root).as_posix())


def prepare(output, version):
    if not re.fullmatch(r'[0-9][A-Za-z0-9._+]*', version):
        raise ValueError('Use an Arch package version without spaces, colons or hyphens')
    files = runtime_files(ROOT)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'index-os-{version}.tar.gz'
    staged = archive.with_suffix('.gz.tmp')
    with staged.open('wb') as destination:
        with gzip.GzipFile(filename='', mode='wb', fileobj=destination, mtime=0, compresslevel=6) as compressed:
            with tarfile.open(fileobj=compressed, mode='w|', format=tarfile.PAX_FORMAT) as tar:
                for path in files:
                    contents = path.read_bytes()
                    relative = path.relative_to(ROOT).as_posix()
                    info = tarfile.TarInfo(f'index-os-{version}/{relative}')
                    info.size = len(contents)
                    info.mode = 0o755 if path.name in ('index-setup', 'index-intro', 'index-askpass.sh') else 0o644
                    info.mtime = info.uid = info.gid = 0
                    info.uname = info.gname = 'root'
                    tar.addfile(info, io.BytesIO(contents))
    staged.replace(archive)
    with archive.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    template = (ROOT / 'packaging/arch/PKGBUILD.in').read_text(encoding='utf-8')
    (output / 'PKGBUILD').write_text(template.replace('@VERSION@', version).replace('@SHA256@', digest), encoding='utf-8', newline='\n')
    (output / 'index-os.install').write_bytes((ROOT / 'packaging/arch/index-os.install').read_bytes())
    (output / 'SHA256SUMS').write_text(f'{digest}  {archive.name}\n', encoding='utf-8', newline='\n')
    print(f'Prepared {len(files)} runtime files: {output}')
    print('On Arch, run makepkg in this directory, then install the generated package with pacman -U.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/arch')
    parser.add_argument('--version', default='0.1.0')
    args = parser.parse_args()
    try:
        prepare(args.output.resolve(), args.version)
    except (OSError, ValueError) as error:
        parser.exit(1, f'Package preparation failed: {error}\n')
