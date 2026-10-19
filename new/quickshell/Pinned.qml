pragma Singleton
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  pinned taskbar apps
//  Windows-style pinned icons. Desktop-entry ids, persisted in
//  ~/.config/index/pinned.json as a plain JSON array.
//
//  ids:        resolved pinned ids (DesktopEntries.byId != null)
//  functions:  isPinned(id) pin(id) unpin(id) toggle(id)
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var defaults: ["org.kde.dolphin", "org.kde.konsole", "systemsettings"]
    readonly property string dir: Quickshell.env("HOME") + "/.config/index"

    // what the file says (may hold ids that don't resolve yet)
    property var raw: defaults.slice()

    // only ids that resolve; re-evaluated when the app list (re)loads
    readonly property var ids: {
        var _apps = DesktopEntries.applications.values
        var out = []
        for (var i = 0; i < root.raw.length; i++) {
            var id = root.raw[i]
            if (out.indexOf(id) < 0 && DesktopEntries.byId(id)) out.push(id)
        }
        return out
    }

    function isPinned(id) { return !!id && root.raw.indexOf(id) >= 0 }

    function pin(id) {
        if (!id || isPinned(id) || !DesktopEntries.byId(id)) return
        save(root.raw.concat([id]))
    }

    function unpin(id) {
        if (!id) return
        save(root.raw.filter(function(x) { return x !== id }))
    }

    function toggle(id) { if (isPinned(id)) unpin(id); else pin(id) }

    function save(list) {
        root.raw = list
        file.setText(JSON.stringify(list, null, 2) + "\n")
    }

    // FileView won't create the parent directory itself
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])

    FileView {
        id: file
        path: root.dir + "/pinned.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var j = JSON.parse(text())
                var arr = Array.isArray(j) ? j : (j && Array.isArray(j.ids) ? j.ids : null)
                if (arr) root.raw = arr.filter(function(x) { return typeof x === "string" && x !== "" })
            } catch (e) {
                console.warn("pinned.json: bad JSON, keeping current list")
            }
        }
        // First run already has defaults; a failed reload must keep current pins.
        onLoadFailed: function(error) { console.warn("pinned.json: load failed, keeping current list") }
    }
}
