// WILL OF THE CITY :: THE INDEX  —  quick settings panel
// Dropdown from the bar: volume, brightness, toggles, quick launches.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: panel
    property bool open: false
    visible: open
    anchors { top: true; right: true }
    margins { top: 32; right: 8 }
    implicitWidth: 320
    implicitHeight: 860
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "index-settings"

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"

    property int vol: 50
    property bool muted: false
    property int bright: 80
    property bool wifiOn: true
    property bool btOn: false
    property bool nightOn: false
    property real mouseSpeed: 0.0
    property bool natScroll: false
    property string scale: "1.0"
    property var wifiList: []
    property var btList: []

    // write mouse settings into rc.xml, then tell labwc to reload
    function applyInput() {
        var rc = "$HOME/.config/labwc/rc.xml"
        var ns = panel.natScroll ? "yes" : "no"
        var sp = panel.mouseSpeed.toFixed(1)
        panel.sh(
            "sed -i '0,/<pointerSpeed>/{s|<pointerSpeed>[^<]*</pointerSpeed>|<pointerSpeed>" + sp + "</pointerSpeed>|}' " + rc +
            " ; sed -i '0,/<naturalScroll>/{s|<naturalScroll>[^<]*</naturalScroll>|<naturalScroll>" + ns + "</naturalScroll>|}' " + rc +
            " ; labwc --reconfigure"
        )
    }

    function sh(c) { Quickshell.execDetached(["sh","-c",c]) }

    // ---- read current state ----
    Process {
        id: readVol
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
        stdout: StdioCollector { onStreamFinished: { var v=parseInt(text.trim()); if(!isNaN(v)) panel.vol=v } }
    }
    Process {
        id: readBright
        command: ["sh","-c","brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector { onStreamFinished: { var v=parseInt(text.trim()); if(!isNaN(v)) panel.bright=v } }
    }
    Process {
        id: readWifi
        command: ["sh","-c","nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: panel.wifiOn = (text.trim()==="enabled") }
    }
    Process {
        id: readBt
        command: ["sh","-c","bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: panel.btOn = (text.trim()==="1") }
    }
    Process {
        id: scanWifi
        command: ["sh","-c","nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list 2>/dev/null | head -8"]
        stdout: StdioCollector { onStreamFinished: {
            var out = []
            var lines = text.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var f = lines[i].split(":")
                if (f.length >= 3 && f[1] !== "")
                    out.push({ active: f[0] === "yes", ssid: f[1], signal: f[2] })
            }
            panel.wifiList = out
        } }
    }
    Process {
        id: scanBt
        command: ["sh","-c","bluetoothctl devices 2>/dev/null | head -8"]
        stdout: StdioCollector { onStreamFinished: {
            var out = []
            var lines = text.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split(" ")
                if (parts[0] === "Device" && parts.length >= 3)
                    out.push({ mac: parts[1], name: parts.slice(2).join(" ") })
            }
            panel.btList = out
        } }
    }

    onOpenChanged: if (open) { readVol.running=true; readBright.running=true; readWifi.running=true; readBt.running=true; scanWifi.running=true; scanBt.running=true }

    Rectangle {
        anchors.fill: parent
        color: "#0a0e16"
        border.color: panel.cyan
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: ">_ SETTINGS_"
                font.family: panel.pixel; font.pixelSize: 17; color: panel.cyanB
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- VOLUME ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: panel.muted ? "VOLUME  MUTE" : "VOLUME  " + panel.vol + "%"
                        font.family: panel.pixel; font.pixelSize: 13
                        color: panel.muted ? panel.warn : panel.cyanB }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: panel.muted ? "[unmute]" : "[mute]"
                        font.family: panel.pixel; font.pixelSize: 12; color: panel.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.muted = !panel.muted
                                panel.sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") } }
                    }
                }
                Rectangle {
                    id: volTrack
                    Layout.fillWidth: true; height: 18
                    color: "#05080d"; border.color: panel.cyanD; border.width: 1
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: (parent.width-4) * panel.vol/100
                        color: panel.muted ? panel.cyanD : panel.cyan
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(m){ set(m.x) }
                        onPositionChanged: function(m){ if(pressed) set(m.x) }
                        function set(x) {
                            panel.vol = Math.max(0, Math.min(100, Math.round(x/volTrack.width*100)))
                            panel.muted = false
                            panel.sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (panel.vol/100).toFixed(2))
                        }
                    }
                }
            }

            // ---------- BRIGHTNESS ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "BRIGHTNESS  " + panel.bright + "%"
                    font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                Rectangle {
                    id: brTrack
                    Layout.fillWidth: true; height: 18
                    color: "#05080d"; border.color: panel.cyanD; border.width: 1
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: (parent.width-4) * panel.bright/100
                        color: panel.cyanB
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(m){ set(m.x) }
                        onPositionChanged: function(m){ if(pressed) set(m.x) }
                        function set(x) {
                            panel.bright = Math.max(5, Math.min(100, Math.round(x/brTrack.width*100)))
                            panel.sh("brightnessctl set " + panel.bright + "%")
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- TOGGLES ----------
            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 8; columnSpacing: 8

                Repeater {
                    model: [
                        { key: "wifi",  label: "WIFI"  },
                        { key: "bt",    label: "BLUETOOTH" },
                        { key: "night", label: "NIGHT LIGHT" },
                        { key: "mic",   label: "MIC MUTE" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 42
                        readonly property bool on:
                            modelData.key === "wifi"  ? panel.wifiOn  :
                            modelData.key === "bt"    ? panel.btOn    :
                            modelData.key === "night" ? panel.nightOn : false
                        color: on ? panel.cyan : "#0c1620"
                        border.color: on ? panel.cyanB : panel.cyanD
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: panel.pixel; font.pixelSize: 12
                            color: parent.on ? "#04141c" : panel.cyanB
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.key === "wifi") {
                                    panel.wifiOn = !panel.wifiOn
                                    panel.sh("nmcli radio wifi " + (panel.wifiOn ? "on" : "off"))
                                } else if (modelData.key === "bt") {
                                    panel.btOn = !panel.btOn
                                    panel.sh("bluetoothctl power " + (panel.btOn ? "on" : "off"))
                                } else if (modelData.key === "night") {
                                    panel.nightOn = !panel.nightOn
                                    panel.sh(panel.nightOn
                                        ? "pkill gammastep; gammastep -O 3500 &"
                                        : "pkill gammastep")
                                } else {
                                    panel.sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- MOUSE ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "MOUSE SPEED  " + (panel.mouseSpeed>0?"+":"") + panel.mouseSpeed.toFixed(1)
                        font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: panel.natScroll ? "[natural scroll: on]" : "[natural scroll: off]"
                        font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.natScroll = !panel.natScroll; panel.applyInput() } }
                    }
                }
                Rectangle {
                    id: msTrack
                    Layout.fillWidth: true; height: 18
                    color: "#05080d"; border.color: panel.cyanD; border.width: 1
                    // -1.0 .. +1.0 mapped onto the bar
                    Rectangle {
                        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.margins: 2
                        x: 2; width: (parent.width-4) * ((panel.mouseSpeed+1)/2)
                        color: panel.cyan
                    }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(m){ set(m.x) }
                        onPositionChanged: function(m){ if(pressed) set(m.x) }
                        onReleased: panel.applyInput()
                        function set(x) {
                            var f = Math.max(0, Math.min(1, x/msTrack.width))
                            panel.mouseSpeed = Math.round((f*2-1)*10)/10
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- DISPLAY ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "DISPLAY"
                    font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: ["1.0", "1.25", "1.5", "2.0"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.fillWidth: true; implicitHeight: 28
                            readonly property bool sel: panel.scale === modelData
                            color: sel ? panel.cyan : "#0c1620"
                            border.color: sel ? panel.cyanB : panel.cyanD; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData + "x"
                                font.family: panel.pixel; font.pixelSize: 12
                                color: parent.sel ? "#04141c" : panel.cyanB }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    panel.scale = modelData
                                    panel.sh("wlr-randr --output \"$(wlr-randr | head -1 | cut -d' ' -f1)\" --scale " + modelData)
                                } }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 30
                    color: dispMa.containsMouse ? "#143245" : "#0c1620"
                    border.color: panel.cyanD; border.width: 1
                    Text { anchors.centerIn: parent; text: ">_ DISPLAY SETTINGS _<"
                        font.family: panel.pixel; font.pixelSize: 12; color: panel.cyanB }
                    MouseArea {
                        id: dispMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.sh("nwg-displays || wdisplays"); panel.open = false }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- WIFI PICKER ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "NETWORKS"; font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                    Item { Layout.fillWidth: true }
                    Text { text: "[scan]"; font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: scanWifi.running = true } }
                }
                Repeater {
                    model: panel.wifiList
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 24
                        color: wMa.containsMouse ? "#143245" : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                            Text {
                                Layout.fillWidth: true
                                text: (modelData.active ? "* " : "  ") + modelData.ssid
                                font.family: panel.pixel; font.pixelSize: 12
                                color: modelData.active ? panel.cyan : panel.cyanB
                                elide: Text.ElideRight
                            }
                            Text { text: modelData.signal + "%"
                                font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD }
                        }
                        MouseArea {
                            id: wMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.sh("nmcli device wifi connect '" + modelData.ssid +
                                "' || nm-connection-editor")
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- BLUETOOTH PICKER ----------
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "BT DEVICES"; font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                    Item { Layout.fillWidth: true }
                    Text { text: "[scan]"; font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.sh("bluetoothctl --timeout 8 scan on"); scanBt.running = true } } }
                }
                Repeater {
                    model: panel.btList
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 24
                        color: bMa.containsMouse ? "#143245" : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 4
                            anchors.right: parent.right; anchors.rightMargin: 4
                            text: modelData.name
                            font.family: panel.pixel; font.pixelSize: 12; color: panel.cyanB
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: bMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.sh("bluetoothctl connect " + modelData.mac)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

            // ---------- QUICK LAUNCH ----------
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [
                        { label: "NET",   cmd: "nm-connection-editor || iwgtk" },
                        { label: "AUDIO", cmd: "pavucontrol" },
                        { label: "BT",    cmd: "blueman-manager || blueberry" },
                        { label: "FILES", cmd: "thunar" },
                        { label: "APPS",  cmd: "$HOME/.local/bin/index-default-apps" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 32
                        color: qlMa.containsMouse ? "#143245" : "#0c1620"
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: modelData.label
                            font.family: panel.pixel; font.pixelSize: 12; color: panel.cyanB
                        }
                        MouseArea {
                            id: qlMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.sh(modelData.cmd); panel.open = false }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
