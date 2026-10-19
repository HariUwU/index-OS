# Attribution

The installer, QML, scripts, configuration and project-authored SVG interface
graphics use GPL-3.0-or-later. See `LICENSE`.

## INDEX Universal font

`assets/PerfectDOSVGA437-Universal.ttf` is the project author's modified font,
extended to support languages missing from the original. It remains the default for KDE, INDEX and the terminal themes. The author
confirmed the modification on 2026-10-19.

The underlying Perfect DOS VGA 437 font is credited to Zeh Fernando. Credit for
the INDEX modifications is separate from credit and applicable terms for the
original font and any additional source glyphs. Keeping the modified font does
not relicense those source glyphs. Original font reference:
https://laemeur.sourceforge.net/fonts/

## Optional personal media

Only intro videos and login background music (`sounds/bg.mp3`) are omitted
from the current source/package. Users can supply those files for local use;
they retain their own terms and are excluded from source/package generation.
The original logo, wallpaper, profile image, power controls, sound effects and
other source font files are retained. The system font remains the author's
modified Universal build. See `assets/README.md` for local file paths.

Other source fonts retain their existing terms: Perfect DOS VGA 437 and its
Thai build, Motiva Sans, Norwester and Gallant. Their presence does not change
the configured KDE/INDEX system font.

The legacy source, screenshots and old build artifacts are local history,
excluded from the publication tree by `.gitignore`; they are not part of the
current runtime package.

## Project identity

This is an unaffiliated fan project inspired by The Index from Project Moon.

The Prescript widget reuses the project's text word bank from
`quickshell/prescript.json`, represented as a QML JavaScript resource in
`kde/plasmoids/org.kde.plasma.index.prescript/contents/code/wordbank.js`.
