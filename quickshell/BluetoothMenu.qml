// WILL OF THE CITY :: THE INDEX  —  bluetooth pairing panel
// Scan / pair / connect / disconnect via bluetoothctl.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: bt
    color: "#0a0e16"
    border.color: "#5DADE2"
    border.width: 2

    signal requestClose()

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"
    readonly property color good:  "#5DE285"

    property bool powered: false
    property bool scanning: false
    property var devices: []
    property string busyMac: ""
    property string note: ""

    function run(cmd) { Quickshell.execDetached(["sh","-c",cmd]) }

    // ---- state ----
    Process {
        id: powerGet
        command: ["sh","-c","bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: bt.powered = (text.trim() === "1") }
    }
    Process {
        id: devGet
        // paired + nearby, marked with connection state
        command: ["sh","-c","{ bluetoothctl devices Paired 2>/dev/null | sed 's/^/P /'; bluetoothctl devices 2>/dev/null | sed 's/^/A /'; } | awk '{mac=$3; $1=$1; print}' | sort -u -k3,3"]
        stdout: StdioCollector { onStreamFinished: {
            var out = [], seen = {}
            var lines = text.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim()
                if (!l) continue
                var parts = l.split(" ")
                if (parts.length < 3) continue
                var paired = parts[0] === "P"
                var mac = parts[2]
                var name = parts.slice(3).join(" ") || mac
                if (seen[mac]) { if (paired) seen[mac].paired = true; continue }
                var d = { mac: mac, name: name, paired: paired, connected: false }
                seen[mac] = d; out.push(d)
            }
            bt.devices = out
            connGet.running = true
        } }
    }
    Process {
        id: connGet
        command: ["sh","-c","bluetoothctl info 2>/dev/null | grep -m1 -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}'"]
        stdout: StdioCollector { onStreamFinished: {
            var mac = text.trim()
            var list = bt.devices
            for (var i = 0; i < list.length; i++) list[i].connected = (list[i].mac === mac)
            bt.devices = list.slice()
        } }
    }
    Timer {
        id: poll
        interval: 3000; running: bt.visible; repeat: true; triggeredOnStart: true
        onTriggered: { powerGet.running = true; devGet.running = true }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text { text: ">_ BLUETOOTH_"; font.family: bt.pixel; font.pixelSize: 16; color: bt.cyanB }
            Item { Layout.fillWidth: true }
            Text {
                text: bt.powered ? "[ON]" : "[OFF]"
                font.family: bt.pixel; font.pixelSize: 12
                color: bt.powered ? bt.good : bt.warn
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { bt.run("bluetoothctl power " + (bt.powered ? "off" : "on")); poll.restart() } }
            }
            Text {
                text: "[X]"; font.family: bt.pixel; font.pixelSize: 12; color: bt.warn
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: bt.requestClose() }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: bt.cyanD; opacity: 0.6 }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; height: 26
                color: bt.scanning ? bt.cyan : "transparent"
                border.color: bt.cyanD; border.width: 1
                Text { anchors.centerIn: parent
                    text: bt.scanning ? "SCANNING..." : "SCAN"
                    font.family: bt.pixel; font.pixelSize: 11
                    color: bt.scanning ? "#04141c" : bt.cyanB }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bt.scanning = true
                        bt.run("bluetoothctl --timeout 12 scan on >/dev/null 2>&1")
                        scanStop.restart()
                    } }
            }
        }
        Timer { id: scanStop; interval: 12000; repeat: false
            onTriggered: { bt.scanning = false; devGet.running = true } }

        Text {
            visible: bt.note !== ""
            Layout.fillWidth: true
            text: bt.note
            font.family: bt.pixel; font.pixelSize: 10; color: bt.cyanD
            wrapMode: Text.WordWrap
        }

        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 3
            model: bt.devices
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 42
                color: dMa.containsMouse ? "#143245" : (modelData.connected ? "#0c2634" : "transparent")
                border.color: modelData.connected ? bt.good : "transparent"
                border.width: 1

                Column {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                    Text {
                        text: modelData.name
                        font.family: bt.pixel; font.pixelSize: 13
                        color: modelData.connected ? bt.cyanB : bt.cyan
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text: (modelData.paired ? "paired" : "new") +
                              (modelData.connected ? " · connected" : "")
                        font.family: bt.pixel; font.pixelSize: 9; color: bt.cyanD
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.connected ? "[DISCONNECT]" : (modelData.paired ? "[CONNECT]" : "[PAIR]")
                    font.family: bt.pixel; font.pixelSize: 10
                    color: modelData.connected ? bt.warn : bt.cyanB
                }
                MouseArea {
                    id: dMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var m = modelData.mac
                        if (modelData.connected) {
                            bt.note = "disconnecting " + modelData.name
                            bt.run("bluetoothctl disconnect " + m)
                        } else if (modelData.paired) {
                            bt.note = "connecting " + modelData.name
                            bt.run("bluetoothctl connect " + m)
                        } else {
                            bt.note = "pairing " + modelData.name + " — confirm any prompt"
                            bt.run("bluetoothctl --agent NoInputNoOutput -- pair " + m +
                                   " && bluetoothctl trust " + m +
                                   " && bluetoothctl connect " + m)
                        }
                        poll.restart()
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: ">_ advanced (blueman) _<"
            font.family: bt.pixel; font.pixelSize: 10; color: bt.cyanD
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { bt.run("blueman-manager || blueberry || true"); bt.requestClose() } }
        }
    }
}
