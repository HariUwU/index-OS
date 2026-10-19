pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: features
    property var selected: ({})
    property bool ready: false
    function enabled(name) { return ready && selected[name] !== false }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/index/features.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const value = JSON.parse(text())
                if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Expected feature object")
                features.selected = value
            } catch (e) { console.warn("Invalid INDEX feature settings") }
            features.ready = true
        }
        onLoadFailed: features.ready = true
    }
}
