// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  top bar (quickshell)
//  A real PanelWindow: emblem, workspaces, clock, tray, date.
//  NOTE: untested in this build — the Quickshell APIs below
//  (Hyprland.workspaces, SystemTray.items, SystemClock) match
//  current docs but may need small tweaks for your qs version.
// ============================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent"

    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property string pixel: "Perfect DOS VGA 437"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: "#0a0e16"

        // glowing bottom border
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

            // ---- left: emblem + workspaces ----
            Text {
                text: "// THE INDEX"
                font.family: bar.pixel; font.pixelSize: 15
                color: bar.cyanB
            }

            RowLayout {
                spacing: 5
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active:
                            Hyprland.focusedWorkspace
                            && Hyprland.focusedWorkspace.id === modelData.id
                        implicitWidth: 22; implicitHeight: 20
                        color: active ? bar.cyan : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: bar.pixel; font.pixelSize: 15
                            color: active ? "#04141c" : bar.cyanD
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + modelData.id)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ---- center: clock ----
            Text {
                text: Qt.formatDateTime(clock.date, "'_'hh:mm AP'._'")
                font.family: bar.pixel; font.pixelSize: 16
                color: bar.cyanB
            }

            Item { Layout.fillWidth: true }

            // ---- right: tray + date ----
            RowLayout {
                spacing: 10
                Repeater {
                    model: SystemTray.items
                    delegate: Image {
                        required property var modelData
                        source: modelData.icon
                        implicitWidth: 16; implicitHeight: 16
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

    // ---- want volume / battery too? add (UPower + Pipewire services):
    //   import Quickshell.Services.UPower
    //   import Quickshell.Services.Pipewire
    // then a Text bound to UPower.displayDevice.percentage, etc.
}
