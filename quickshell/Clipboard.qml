// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  clipboard history (Win+V)
//  Popup near the top centre of the main screen, newest first.
//  Data: cliphist (filled by session/index-clipboard.service).
//  Enter / click copies an entry back to the clipboard and closes,
//  Up/Down move, Delete removes one, CLEAR ALL wipes, Esc closes.
// ============================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Scope {
    id: cb

    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"
    readonly property string pixel: "Perfect DOS VGA 437 Universal"

    readonly property bool open: UiState.clipboardOpen
    property var entries: []      // [{ id: "123", text: "...", image: bool }]
    property bool loaded: false

    onOpenChanged: if (open) refresh()

    function close(): void { UiState.clipboardOpen = false }

    function refresh(): void {
        loaded = false
        if (!listProc.running) listProc.running = true
    }

    // cliphist ids are plain numbers; never hand anything else to a shell
    function validId(id): bool { return /^[0-9]+$/.test(String(id)) }

    function copyAt(i): void {
        if (i < 0 || i >= entries.length) return
        var id = entries[i].id
        if (!validId(id)) return
        // id goes in as $1, never pasted into the script text
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t' \"$1\" | cliphist decode | wl-copy", "sh", id])
        close()
    }

    function removeAt(i): void {
        if (i < 0 || i >= entries.length) return
        var id = entries[i].id
        if (!validId(id)) return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", id])
        var keep = entries.slice()
        keep.splice(i, 1)
        entries = keep
        list.currentIndex = Math.min(i, entries.length - 1)
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"])
        entries = []
    }

    Process {
        id: listProc
        // "id<TAB>preview", newest first; 30 is plenty for a picker
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 30"]
        stdout: StdioCollector { onStreamFinished: {
            var out = []
            var lines = text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                var tab = line.indexOf("\t")
                if (tab <= 0) continue
                var id = line.slice(0, tab)
                if (!cb.validId(id)) continue
                var prev = line.slice(tab + 1)
                var img = /^\[\[ binary data/.test(prev)
                out.push({ id: id, image: img,
                           text: img ? "[image]" : Glyph.clean(prev.replace(/\s+/g, " ").trim()) })
            }
            cb.entries = out
            cb.loaded = true
            list.currentIndex = 0
            list.positionViewAtBeginning()
        } }
    }

    // click anywhere outside the popup to close it
    PanelWindow {
        screen: Screens.main
        visible: cb.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "index-clipboard-dismiss"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: cb.close()
        }
    }

    PanelWindow {
        id: win
        screen: Screens.main
        visible: cb.open
        // only the top edge is anchored, so the layer is centred horizontally
        anchors { top: true }
        margins { top: 72 }
        implicitWidth: 440
        implicitHeight: 460
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "index-clipboard"
        onVisibleChanged: if (visible) keys.forceActiveFocus()

        Rectangle {
            anchors.fill: parent
            color: "#0a0e16"
            border.color: cb.cyan; border.width: 2
            opacity: cb.open ? 1 : 0
            transform: Translate { y: cb.open ? 0 : -18
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // keyboard handling for the whole popup
            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: cb.close()
                Keys.onUpPressed:     list.decrementCurrentIndex()
                Keys.onDownPressed:   list.incrementCurrentIndex()
                Keys.onReturnPressed: cb.copyAt(list.currentIndex)
                Keys.onEnterPressed:  cb.copyAt(list.currentIndex)
                Keys.onDeletePressed: cb.removeAt(list.currentIndex)
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: ">_ CLIPBOARD_"; font.family: cb.pixel; font.pixelSize: 16; color: cb.cyanB }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: cb.entries.length > 0
                        text: "[CLEAR ALL]"; font.family: cb.pixel; font.pixelSize: 11; color: cb.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: cb.wipe() }
                    }
                    Text {
                        text: "[X]"; font.family: cb.pixel; font.pixelSize: 12; color: cb.warn
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: cb.close() }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: cb.cyanD; opacity: 0.6 }

                Text {
                    visible: cb.entries.length === 0
                    Layout.fillWidth: true
                    text: cb.loaded ? "  nothing copied yet." : "  reading..."
                    font.family: cb.pixel; font.pixelSize: 12; color: cb.cyanD
                }

                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 3
                    model: cb.entries
                    currentIndex: 0
                    highlightMoveDuration: 90
                    keyNavigationWraps: true
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool selected: list.currentIndex === index
                        width: ListView.view.width; height: 30
                        color: (rowMa.containsMouse || selected) ? cb.cyanD : "#0c1620"
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: delBtn.left; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            font.family: cb.pixel; font.pixelSize: 13
                            font.italic: modelData.image
                            color: (rowMa.containsMouse || parent.selected) ? "#04141c"
                                 : (modelData.image ? cb.cyan : cb.cyanB)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            textFormat: Text.PlainText
                        }
                        MouseArea {
                            id: rowMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: cb.copyAt(index)
                        }
                        // per-row delete; declared after rowMa so it gets the click
                        Text {
                            id: delBtn
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "[DEL]"
                            font.family: cb.pixel; font.pixelSize: 10
                            color: (rowMa.containsMouse || parent.selected) ? "#04141c" : cb.warn
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cb.removeAt(index) }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "enter: copy   del: remove   esc: close"
                    font.family: cb.pixel; font.pixelSize: 10; color: cb.cyanD
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
