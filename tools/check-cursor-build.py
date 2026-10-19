#!/usr/bin/env python3
"""Validate real xcursorgen output against the INDEX role manifest."""
from pathlib import Path
import struct
import sys

theme = Path(sys.argv[1])
manifest = Path(__file__).resolve().parent.parent / 'cursor/index-needle/roles.tsv'
total = 0
for line in manifest.read_text().splitlines():
    if not line.strip() or line.startswith('#'):
        continue
    role, hx, hy, delay, *frames = line.split()
    data = (theme / 'cursors' / role).read_bytes()
    magic, header, version, count = struct.unpack_from('<4I', data)
    assert magic == 0x72756358 and header == 16, role
    assert count == 3 * len(frames), (role, count)
    sizes = {}
    for i in range(count):
        kind, size, offset = struct.unpack_from('<3I', data, header + i * 12)
        assert kind == 0xfffd0002 and size in (24, 32, 48), role
        chunk_header, chunk_type, subtype, image_version, width, height, x, y, ms = struct.unpack_from('<9I', data, offset)
        assert chunk_header == 36 and chunk_type == kind and subtype == size and image_version == 1, role
        assert width == height == size and ms == int(delay), role
        assert (x, y) == ((int(hx) * size + 16) // 32, (int(hy) * size + 16) // 32), role
        assert offset + 36 + width * height * 4 <= len(data), role
        sizes[size] = sizes.get(size, 0) + 1
    assert all(sizes.get(size) == len(frames) for size in (24, 32, 48)), role
    total += 1
aliases = manifest.with_name('aliases.tsv')
for line in aliases.read_text().splitlines():
    if line.strip() and not line.startswith('#'):
        alias, target = line.split()
        path = theme / 'cursors' / alias
        assert path.is_symlink() and path.readlink() == Path(target) and path.is_file(), alias
print(f'PASS: {total} real Xcursor roles, 24/32/48 sizes, hotspots, animation timing and aliases')
