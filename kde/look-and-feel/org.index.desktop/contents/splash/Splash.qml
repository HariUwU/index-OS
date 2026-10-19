// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Rectangle {
    id: root
    color: "#05080c"
    property int stage: 0

    Text {
        id: emblem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: label.top
        anchors.bottomMargin: 36
        width: Math.min(root.width * 0.22, 200)
        height: width
        text: logoImage.status === Image.Ready ? "" : ">_INDEX"
        color: "#85c5e8"
        font.family: "Perfect DOS VGA 437 Universal"
        font.pixelSize: Math.min(36, width / 4)
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        Image {
            id: logoImage
            anchors.fill: parent
            source: "../assets/Logo.png"
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }
        opacity: 0
        NumberAnimation on opacity { from: 0; to: 1; duration: 500 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: "// THE INDEX"
        color: "#85c5e8"
        font.family: "Perfect DOS VGA 437 Universal"
        font.pixelSize: 28
    }

    Rectangle {
        id: progressTrack
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: label.bottom
        anchors.topMargin: 24
        width: Math.min(root.width * 0.4, 360)
        height: 2
        color: "#1b3448"

        Rectangle {
            width: parent.width * Math.min(1, Math.max(0.05, root.stage / 6))
            height: parent.height
            color: "#5dade2"
            Behavior on width { NumberAnimation { duration: 180 } }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: progressTrack.bottom
        anchors.topMargin: 16
        text: "The Index keeps what the City forgets."
        color: "#5dade2"
        font.family: "Perfect DOS VGA 437 Universal"
        font.pixelSize: 14
    }
}
