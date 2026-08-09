# Extending the pixel font

`build.py` adds Cyrillic and Greek to Perfect DOS VGA 437, drawn on the same
8x16 pixel grid so Russian, Ukrainian, Greek and German text keep the CRT look
instead of falling back to Noto.

    python3 build.py ../../assets/PerfectDOSVGA437.ttf ../../assets/PerfectDOSVGA437-Ext.ttf

`glyphs.py` holds the bitmaps: `CAP` and `LOW` are hand-drawn glyphs (one 16-row
string of 8 chars each), `ALIAS` maps codepoints that reuse an existing Latin
shape (А→A, Ο→O, and so on).

To add more: draw the bitmap in `glyphs.py`, re-run `build.py`, reinstall.
