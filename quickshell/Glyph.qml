pragma Singleton
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  glyph cleanup
//  The pixel font lacks several Unicode punctuation glyphs and
//  renders them as junk. clean() maps them to plain ASCII.
//  Use on every piece of EXTERNAL text (titles, notifications...).
// ============================================================

import QtQuick
import Quickshell

Singleton {
    function clean(s) {
        if (s === undefined || s === null) return ""
        return String(s)
            .replace(/[—–‒―]/g, "-")
            .replace(/…/g, "...")
            .replace(/[‘’‚‛]/g, "'")
            .replace(/[“”„‟]/g, "\"")
            .replace(/[•●·]/g, "*")
            .replace(/[   ]/g, " ")
    }
}
