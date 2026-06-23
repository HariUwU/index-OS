// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  top bar (quickshell)
//  PanelWindow: emblem(start menu), workspaces, clock, tray, date.
//  + custom START MENU popup (apps + search + power).
//  NOTE: untested — Quickshell APIs (Hyprland.workspaces,
//  SystemTray.items, SystemClock, DesktopEntries, PopupWindow)
//  match current docs but may need small tweaks per qs version.
// ============================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent"
    WlrLayershell.keyboardFocus: bar.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"
    readonly property string pixel: "Perfect DOS VGA 437"

    property bool menuOpen: false
    property int  activeWs: 1

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: "#0a0e16"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: bar.cyan
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 12

            // ---- emblem = START button ----
            Text {
                text: "// THE INDEX"
                font.family: bar.pixel; font.pixelSize: 15
                color: (startArea.containsMouse || bar.menuOpen) ? "#ffffff" : bar.cyanB
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: startArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.menuOpen = !bar.menuOpen
                }
            }

            RowLayout {
                spacing: 5
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property int ws: index + 1
                        readonly property bool active: bar.activeWs === ws
                        implicitWidth: 22; implicitHeight: 20
                        color: active ? bar.cyan : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: ws
                            font.family: bar.pixel; font.pixelSize: 15
                            color: active ? "#04141c" : bar.cyanD
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bar.activeWs = ws
                                // labwc has no workspace IPC; simulate Super+N (rc.xml GoToDesktop)
                                Quickshell.execDetached(["wtype","-M","logo","-k", String(ws), "-m","logo"])
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Qt.formatDateTime(clock.date, "'_'hh:mm AP'._'")
                font.family: bar.pixel; font.pixelSize: 16
                color: bar.cyanB
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 10
                // volume control — scroll to change, click to mute (wireplumber)
                Text {
                    id: volText
                    property int vol: 50
                    property bool muted: false
                    text: muted ? "VOL MUTE" : "VOL " + vol
                    font.family: bar.pixel; font.pixelSize: 13
                    color: muted ? bar.warn : bar.cyanD
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            volText.muted = !volText.muted
                            Quickshell.execDetached(["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"])
                        }
                        onWheel: function(w) {
                            var d = w.angleDelta.y > 0 ? 5 : -5
                            volText.vol = Math.max(0, Math.min(100, volText.vol + d))
                            volText.muted = false
                            Quickshell.execDetached(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@", (volText.vol/100).toFixed(2)])
                        }
                    }
                }
                Repeater {
                    model: SystemTray.items
                    delegate: Image {
                        required property var modelData
                        source: modelData.icon
                        width: 16; height: 16
                        sourceSize.width: 16; sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.LeftButton) modelData.activate()
                                else if (modelData.hasMenu) modelData.display(bar, width/2, height)
                            }
                        }
                    }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                    font.family: bar.pixel; font.pixelSize: 13
                    color: bar.cyanD
                }
            }
        }
    }

    // ===================== START MENU =====================
    PopupWindow {
        id: startMenu
        visible: bar.menuOpen
        anchor.window: bar
        anchor.rect.x: 8
        anchor.rect.y: bar.implicitHeight
        implicitWidth: 340
        implicitHeight: 480
        color: "transparent"

        property string query: ""
        property var shownApps: {
            var all = DesktopEntries.applications.values
            if (!all) return []
            if (startMenu.query.length === 0) return all
            var q = startMenu.query.toLowerCase()
            return all.filter(function(a) {
                return (a.name || "").toLowerCase().indexOf(q) >= 0
            })
        }

        Rectangle {
            anchors.fill: parent
            color: "#05080d"
            border.color: bar.cyan
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: ">_ THE INDEX // START_"
                    font.family: bar.pixel; font.pixelSize: 16; color: bar.cyanB
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: bar.cyanD; opacity: 0.6 }

                // search
                Rectangle {
                    Layout.fillWidth: true; height: 32
                    color: "#0a0e16"; border.color: bar.cyanD; border.width: 1
                    TextInput {
                        id: search
                        anchors.fill: parent; anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: bar.pixel; font.pixelSize: 15; color: bar.cyanB
                        focus: bar.menuOpen
                        onTextChanged: startMenu.query = text
                        Keys.onEscapePressed: bar.menuOpen = false
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: search.text.length === 0
                            text: "search._"; color: bar.cyanD
                            font.family: bar.pixel; font.pixelSize: 15
                        }
                    }
                }

                // app list
                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    model: startMenu.shownApps
                    delegate: Rectangle {
                        required property var modelData
                        width: appList.width; height: 30
                        color: appArea.containsMouse ? bar.cyanD : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8
                            text: modelData.name
                            font.family: bar.pixel; font.pixelSize: 15
                            color: appArea.containsMouse ? "#04141c" : bar.cyanB
                            elide: Text.ElideRight
                            width: parent.width - 16
                        }
                        MouseArea {
                            id: appArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { modelData.execute(); bar.menuOpen = false }
                        }
                    }
                }

                // power row
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [
                            { label: "LOCK",   cmd: ["sh","-c","pgrep -f lock/lock.qml || quickshell -p ~/.config/quickshell/lock/lock.qml"] },
                            { label: "REBOOT", cmd: ["systemctl", "reboot"] },
                            { label: "OFF",    cmd: ["systemctl", "poweroff"] }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; height: 30
                            color: powArea.containsMouse ? bar.warn : "transparent"
                            border.color: bar.warn; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: bar.pixel; font.pixelSize: 12
                                color: powArea.containsMouse ? "#04141c" : bar.warn
                            }
                            MouseArea {
                                id: powArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Quickshell.execDetached(modelData.cmd); bar.menuOpen = false }
                            }
                        }
                    }
                }
            }
        }
    }
}
