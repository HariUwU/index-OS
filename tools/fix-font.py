#!/usr/bin/env python3
# ============================================================
#  WILL OF THE CITY :: THE INDEX  —  repair Perfect DOS VGA 437 Universal
#
#  The Universal build maps the Windows-1252 specials (U+2026 …, U+2014 —,
#  U+2018 ‘, …) to the CP437 glyph at the same byte, so "…" draws as "à"
#  and "—" as "ù". This remaps them to correct glyphs, draws a real
#  ellipsis and em dash, and drops the ones the font can't show so Qt
#  falls back to another font instead of drawing the wrong letter.
#
#  Usage:  python3 fix-font.py IN.ttf OUT.ttf      (needs python-fonttools)
# ============================================================

import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

# broken code point -> existing glyph that looks right (by name of a Unicode char)
REMAP = {
    0x2018: "'", 0x2019: "'", 0x201A: ",", 0x2039: "<", 0x203A: ">",
    0x201C: '"', 0x201D: '"', 0x201E: '"',
    0x2013: "-", 0x02C6: "^", 0x02DC: "~",
}
DRAWN = (0x2026, 0x2014)   # ellipsis, em dash: drawn below


def outline(gs, name):
    p = RecordingPen()
    gs[name].draw(p)
    return str(p.value)


def bounds(gs, name):
    p = BoundsPen(gs)
    gs[name].draw(p)
    return p.bounds


def boxes(rects):
    pen = TTGlyphPen(None)
    for x0, y0, x1, y1 in rects:
        pen.moveTo((x0, y0)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y0))
        pen.closePath()
    return pen.glyph()


def main(src, dst):
    font = TTFont(src)
    cmap = font.getBestCmap()
    gs = font.getGlyphSet()

    # only touch code points that really share a CP437 letter's drawing
    broken = []
    for b in range(0x80, 0xA0):
        try:
            u = ord(bytes([b]).decode("cp1252"))
        except UnicodeDecodeError:
            continue
        v = ord(bytes([b]).decode("cp437"))
        gu, gv = cmap.get(u), cmap.get(v)
        if gu and gv and (gu == gv or outline(gs, gu) == outline(gs, gv)):
            broken.append(u)

    adv = font["hmtx"][cmap[ord(".")]][0]
    px = adv // 9                                   # VGA cell is 9 px wide
    _, dy0, _, dy1 = bounds(gs, cmap[ord(".")])
    _, hy0, _, hy1 = bounds(gs, cmap[ord("-")])
    new = {
        0x2026: ("index.ellipsis", boxes([(x * px, dy0, (x + 1) * px, dy0 + px) for x in (1, 4, 7)])),
        0x2014: ("index.emdash", boxes([(0, hy0, adv, hy1)])),
    }
    for cp, (name, glyph) in new.items():
        if cp in broken:
            font["glyf"][name] = glyph          # also appends to the glyph order
            font["hmtx"][name] = (adv, 0)
    order = font.getGlyphOrder()

    fixed, dropped = [], []
    for table in font["cmap"].tables:
        if not table.isUnicode():
            continue
        for cp in broken:
            if cp not in table.cmap:
                continue
            if cp in DRAWN:
                table.cmap[cp] = new[cp][0]
            elif cp in REMAP:
                table.cmap[cp] = cmap[ord(REMAP[cp])]
            else:
                del table.cmap[cp]
    for cp in broken:
        (fixed if cp in DRAWN or cp in REMAP else dropped).append(chr(cp))

    font["maxp"].numGlyphs = len(order)
    font.save(dst)
    print("fixed:", " ".join(fixed) or "-")
    print("dropped (fallback font):", " ".join(dropped) or "-")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__ or "usage: fix-font.py IN.ttf OUT.ttf")
    main(sys.argv[1], sys.argv[2])
