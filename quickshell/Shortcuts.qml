// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  Windows-style shortcuts
//  kwin-bridge.js registers the keys, the bridge turns them into
//  KWin.shortcut(name), and this file decides what each one does.
//  Non-visual. (Meta+E / Meta+I / Meta+D are KDE's own defaults
//  and normally never reach here; files/settings are handled
//  anyway in case they are bound to the bridge later.)
// ============================================================

import QtQuick
import Quickshell
import "."

Scope {
    Connections {
        target: KWin
        function onShortcut(name) {
            switch (name) {
            case "files":         Quickshell.execDetached(["dolphin"]); break
            case "clipboard":     if (Features.enabled("clipboard")) UiState.toggleClipboard(); break
            case "quicksettings": if (Features.enabled("quicksettings")) UiState.toggleQuickSettings(); break
            case "screenshot":
                // Win+Shift+S: pick a region, copy it, no editor window.
                // Spectacle 6 has --copy-image (-C); older ones only had --clipboard.
                Quickshell.execDetached(["sh", "-c",
                    "if spectacle --help 2>/dev/null | grep -q -- --copy-image; then " +
                    "exec spectacle --region --background --copy-image; " +
                    "else exec spectacle --region --background --clipboard; fi"])
                break
            case "taskmgr":       Quickshell.execDetached(["plasma-systemmonitor"]); break
            case "settings":      Quickshell.execDetached(["systemsettings"]); break
            }
        }
    }
}
