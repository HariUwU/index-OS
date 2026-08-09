// WILL OF THE CITY :: THE INDEX  —  notifications
// Top-right stacked popups, cyan CRT style. Click to dismiss.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "."

PanelWindow {
    id: notifRoot
    anchors { top: true; right: true }
    margins { top: 40; right: 12 }
    implicitWidth: 380
    implicitHeight: Math.max(1, col.implicitHeight)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "index-notifications"
    visible: col.children.length > 0

    readonly property string pixel: "Perfect DOS VGA 437 Universal"

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: function (n) {
            n.tracked = true
            // DeviceWatch already plays its own connect/disconnect cue
            if ((n.appName || "").indexOf("DEVICE") < 0)
                Sfx.play(n.urgency === NotificationUrgency.Critical ? "error" : "notify")
            NotifHistory.add(n.appName, n.summary, n.body,
                             n.urgency === NotificationUrgency.Critical)
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        Repeater {
            model: server.trackedNotifications

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: inner.implicitHeight + 20
                color: "#0a0e16"
                border.color: modelData.urgency === NotificationUrgency.Critical ? "#FF6B6B" : "#5DADE2"
                border.width: 2
                opacity: 0.0
                property real slide: 70
                transform: Translate { x: slide }
                Component.onCompleted: { opacity = 0.97; slide = 0 }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                Behavior on slide { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: inner
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: ">_"
                            font.family: notifRoot.pixel; font.pixelSize: 13
                            color: "#3A7CA5"
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.appName || "SYSTEM"
                            font.family: notifRoot.pixel; font.pixelSize: 12
                            color: "#3A7CA5"
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "[X]"
                            font.family: notifRoot.pixel; font.pixelSize: 12
                            color: "#FF6B6B"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.dismiss()
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.summary
                        font.family: notifRoot.pixel; font.pixelSize: 16
                        color: "#85C5E8"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: (modelData.body || "") !== ""
                        text: modelData.body
                        font.family: notifRoot.pixel; font.pixelSize: 13
                        color: "#5DADE2"
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: modelData.dismiss()
                    z: -1
                }

                // auto-dismiss (critical stays)
                Timer {
                    interval: 6000
                    running: modelData.urgency !== NotificationUrgency.Critical
                    repeat: false
                    onTriggered: modelData.dismiss()
                }
            }
        }
    }
}
