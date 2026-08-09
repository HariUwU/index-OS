#!/usr/bin/env python3
"""Extend Perfect DOS VGA 437 with Cyrillic + Greek drawn on the same pixel grid."""
import sys
sys.path.insert(0, '/home/claude/fontwork')
from glyphs import CAP, LOW, ALIAS
from fontTools.ttLib import TTFont, newTable
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables._g_l_y_f import Glyph

SRC = sys.argv[1]
DST = sys.argv[2]
PX  = 256            # units per pixel
TOP = 12             # row 0 sits at y = TOP*PX
ADV = 2304

f = TTFont(SRC)
glyf, hmtx, cmap = f['glyf'], f['hmtx'], f.getBestCmap()
order = f.getGlyphOrder()

def name_for(cp): return "uni%04X" % cp

def rects_from_bitmap(rows):
    """merge horizontal runs per row into rectangles"""
    out = []
    for r, row in enumerate(rows):
        c = 0
        while c < 8:
            if row[c] == '#':
                s = c
                while c < 8 and row[c] == '#': c += 1
                out.append((s, r, c, r+1))
            else:
                c += 1
    return out

def build_glyph(rows):
    pen = TTGlyphPen(None)
    for x0, r0, x1, r1 in rects_from_bitmap(rows):
        X0, X1 = x0*PX, x1*PX
        Y1, Y0 = (TOP-r0)*PX, (TOP-r1)*PX
        pen.moveTo((X0, Y0)); pen.lineTo((X0, Y1))
        pen.lineTo((X1, Y1)); pen.lineTo((X1, Y0)); pen.closePath()
    return pen.glyph()

added = 0
newmap = {}

# 1. drawn glyphs
for table in (CAP, LOW):
    for cp, rows in table.items():
        gn = name_for(cp)
        if gn not in glyf.glyphs:
            glyf.glyphs[gn] = build_glyph(rows)
            hmtx[gn] = (ADV, 0)
            order.append(gn)
        newmap[cp] = gn
        added += 1

# 2. aliases: point at the existing Latin glyph
for cp, ch in ALIAS.items():
    src_gn = cmap.get(ord(ch))
    if not src_gn: continue
    newmap[cp] = src_gn
    added += 1

f.setGlyphOrder(order)
glyf.glyphOrder = order
# merge into every unicode cmap subtable, and add a format-4 if needed
for st in f['cmap'].tables:
    if st.isUnicode():
        st.cmap.update(newmap)


f['OS/2'].usFirstCharIndex = 0x20
f['OS/2'].usLastCharIndex = 0xFFFF

# rename so it can live alongside the original
for rec in f['name'].names:
    try: v = rec.toUnicode()
    except Exception: continue
    if rec.nameID in (1, 3, 4, 6, 16):
        nv = v.replace('Perfect DOS VGA 437', 'Perfect DOS VGA 437 Ext')
        if rec.nameID == 6: nv = nv.replace(' ', '')
        rec.string = nv
f.save(DST)
print("added/mapped %d codepoints -> %s" % (added, DST))
