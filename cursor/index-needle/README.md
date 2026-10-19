# INDEX Needle

Review build of selected concept B. The default pointer reuses the approved native
SVG paths exactly. All cursor sources have transparent 32 × 32 viewBoxes, cyan
`#5DADE2` / `#85C5E8` fills, white `#e6f2fa` edges and dark `#05080d` outlines.

Open [cursor-family-preview.svg](cursor-family-preview.svg) or its PNG sibling to
review the entire family. Pixel lettering is outlined from the repository's
existing Perfect DOS font; no font installation is needed. The preview shows 2×
enlargements and 24/32/48 px samples on dark and light backgrounds. View at 100%
zoom for actual-size samples. Busy/progress frame strips show their full sequence.

## Build only

On Linux, supply Bash 4+, `rsvg-convert` (librsvg; often packaged as `librsvg2-bin`
or `librsvg`) and `xcursorgen` (`xorg-xcursorgen` on Arch). This project does not
install dependencies. From this directory:

```sh
bash build.sh                        # ./build/index-needle
bash build.sh ./build/review-needle  # exact output theme directory
bash build.sh "/path/to/task-owned/review output/index-needle"
```

Relative output paths are relative to your current working directory. The default
is always this source directory's `build/index-needle`. Use a new directory for
each build: existing files, directories and symlinks are refused. No output is
overwritten or recursively removed. Failed builds retain partial output for
inspection; choose another fresh directory when retrying.

Output contains `index.theme`, `cursors/` (Xcursor binaries and direct relative
aliases), and `.build/` (PNGs and xcursorgen configs for inspection). It is not
installed, registered or activated. No desktop settings, environment variables,
theme selectors or installer files are changed. Fallback is `breeze_cursors`
when that theme is available in the eventual review environment.

## Sources and hotspots

`roles.tsv` is the build manifest: role, X/Y hotspot in the source 32 px viewBox,
frame delay in milliseconds, then ordered SVG filenames from `src/`. SVG comments
repeat each hotspot. `aliases.tsv` supplies common Xcursor, CSS and Qt names.
Unimplemented roles (for example help and drag-copy) use the inherited theme;
legacy application-specific hashed aliases are not supplied.

| Role | Source hotspot | 24 px | 32 px | 48 px |
| --- | --- | --- | --- | --- |
| Default, progress | 3, 3 | 2, 2 | 3, 3 | 5, 5 |
| Link | 13, 3 | 10, 2 | 13, 3 | 20, 5 |
| Text, resize EW/NS/NWSE/NESW, move, crosshair, busy, not-allowed, grab, grabbing | 16, 16 | 12, 12 | 16, 16 | 24, 24 |

Hotspots scale with `(coordinate * size + 16) / 32`, using integer division
(nearest pixel, ties rounded up). Progress preserves the default pointer's
hotspot. Busy/progress each contain eight SVG frames at 80 ms per frame, a
640 ms loop. Multiple same-size entries follow the
[X.Org xcursorgen configuration format](https://xorg.freedesktop.org/archive/X11R7.0/doc/html/xcursorgen.1.html).

## Validation

Creation-session results (Windows): all 28 SVG sources parsed; 84 actual-size PNG
renders at 24/32/48 px passed dimension, transparency and nonempty-art checks using
the bundled Sharp renderer. The Bash mock-tool smoke test passed, including all
14 role configs and 67 aliases. The default SVG path attributes exactly match
selected draft B. A real build with `rsvg-convert` and `xcursorgen` also succeeded
in the CachyOS VM. The resulting theme is kept in a review directory; it has not
been activated.

```sh
bash tests/check-build.sh
```

This dependency-free smoke test uses explicitly labeled stand-ins for the two
Linux tools. It checks build orchestration, hotspots, frame order/delays, aliases,
paths containing spaces, missing dependencies and existing-output protection.
Artifacts remain inside a newly created `build/test-*/` directory. The stand-ins
do not create real PNGs or Xcursor binaries and do not certify the Linux toolchain.
Use `bash build.sh ./build/linux-review` with the real tools for that verification.
The optional cursor selection in `setup.sh` builds these files into the user
icons directory with a backup on reruns. It leaves the current pointer active.
