pragma Singleton
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  which screen is "main"
//  The bar, Prescript and every popup live on ONE screen. Without
//  this each PanelWindow picks its own default, and with two
//  monitors popups could open on the other screen. Main = the
//  screen at the top-left of the layout (KDE's usual primary).
// ============================================================

import QtQuick
import Quickshell

Singleton {
    readonly property var main: {
        var all = Quickshell.screens
        for (var i = 0; i < all.length; i++)
            if (all[i].x === 0 && all[i].y === 0) return all[i]
        return all.length ? all[0] : null
    }
}
