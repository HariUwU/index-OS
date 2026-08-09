// WILL OF THE CITY :: THE INDEX  —  notification history (singleton)
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property var items: []          // newest first
    readonly property int maxItems: 60

    function add(app, summary, body, critical) {
        var list = root.items.slice()
        list.unshift({
            app: app || "SYSTEM",
            summary: summary || "",
            body: body || "",
            critical: critical || false,
            time: Qt.formatDateTime(new Date(), "hh:mm")
        })
        if (list.length > root.maxItems) list = list.slice(0, root.maxItems)
        root.items = list
    }
    function clear() { root.items = [] }
}
