// WILL OF THE CITY :: THE INDEX  —  quick settings panel
// Opens from the bar. Volume, brightness, toggles, shortcuts to real tools.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Rectangle {
    id: panel
    color: "#0a0e16"
    opacity: visible ? 1 : 0
    transform: Translate { y: panel.visible ? 0 : -18
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    border.color: "#5DADE2"
    border.width: 2

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"

    property int volume: 50
    property int brightness: 70
    property bool btOn: false
    property string netName: ""
    property int  batPct: -1
    property string batStatus: ""
    property int  batTimeMin: -1
    property string lidAction: "suspend"     // suspend | lock | ignore
    property bool hasLid: false
    property var autostartApps: []

    signal requestClose()
    signal requestIntroSettings()

    function run(cmd) { Quickshell.execDetached(["sh","-c",cmd]) }

    // pull fresh values every time the panel appears
    onVisibleChanged: if (visible) panel.refresh()
    Component.onCompleted: panel.refresh()
    function refresh(): void {
        volGet.running=true; briGet.running=true; btGet.running=true; netGet.running=true
        batGet.running=true; batTimeGet.running=true; lidGet.running=true; lidDetect.running=true
        autostartGet.running=true
    }

    // ---- pollers ----
    Process {
        id: volGet
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
        stdout: StdioCollector { onStreamFinished: { var v=parseInt(text.trim()); if(!isNaN(v)) panel.volume=v } }
    }
    Process {
        id: briGet
        command: ["sh","-c","brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector { onStreamFinished: { var v=parseInt(text.trim()); if(!isNaN(v)) panel.brightness=v } }
    }
    Process {
        id: btGet
        command: ["sh","-c","[ -d /sys/class/bluetooth ] || exit 0; timeout -k 1 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: panel.btOn = (text.trim()==="1") }
    }
    Process {
        id: netGet
        command: ["sh","-c","nmcli -t -f NAME connection show --active 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: panel.netName = text.trim() }
    }
    Process {
        id: batGet
        command: ["sh","-c","c=/sys/class/power_supply/BAT0; [ -d $c ] || c=/sys/class/power_supply/BAT1; if [ -d $c ]; then printf '%s|%s' \"$(cat $c/capacity)\" \"$(cat $c/status)\"; else printf -- '-1|none'; fi"]
        stdout: StdioCollector { onStreamFinished: {
            var f = text.trim().split("|")
            var v = parseInt(f[0]); panel.batPct = isNaN(v) ? -1 : v
            panel.batStatus = f[1] || ""
        } }
    }
    Process {
        id: batTimeGet
        command: ["sh","-c","upower -i $(upower -e 2>/dev/null | grep -m1 BAT) 2>/dev/null | grep -E 'time to (empty|full)' | head -1 | grep -oE '[0-9.]+ (hours|minutes)' | awk '{if($2==\"hours\") print int($1*60); else print int($1)}'"]
        stdout: StdioCollector { onStreamFinished: { var v=parseInt(text.trim()); panel.batTimeMin = isNaN(v) ? -1 : v } }
    }
    Process {
        id: autostartGet
        command: ["sh","-c","d=$HOME/.config/autostart; mkdir -p $d; for f in $d/*.desktop; do [ -f \"$f\" ] || continue; n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2); printf '%s|%s\\n' \"$(basename \"$f\")\" \"$n\"; done"]
        stdout: StdioCollector { onStreamFinished: {
            var out=[], lines=text.trim().split("\n")
            for (var i=0;i<lines.length;i++){
                if(!lines[i]) continue
                var f=lines[i].split("|")
                out.push({ file: f[0], name: f[1] || f[0].replace(".desktop","") })
            }
            panel.autostartApps = out
        } }
    }
    Process {
        id: lidDetect
        command: ["sh","-c","[ -e /proc/acpi/button/lid ] || ls /proc/acpi/button/lid* >/dev/null 2>&1 || grep -qi 'switch' /proc/bus/input/devices 2>/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: panel.hasLid = (text.trim() === "1") }
    }
    Process {
        id: lidGet
        command: ["sh","-c","grep -h '^HandleLidSwitch=' /etc/systemd/logind.conf.d/*.conf /etc/systemd/logind.conf 2>/dev/null | tail -1 | cut -d= -f2"]
        stdout: StdioCollector { onStreamFinished: { var v=text.trim(); if(v) panel.lidAction = (v==="suspend"?"suspend":(v==="lock"?"lock":"ignore")) } }
    }
    Timer {
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        // Only poll live system state. Saved input/idle preferences are loaded
        // by refresh() when the panel opens, so an old async read cannot undo a click.
        onTriggered: { volGet.running=true; briGet.running=true; btGet.running=true; netGet.running=true;
                       batGet.running=true; batTimeGet.running=true; lidGet.running=true;
                       lidDetect.running=true; autostartGet.running=true }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // header
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: ">_ SETTINGS_"
                font.family: panel.pixel; font.pixelSize: 17; color: panel.cyanB
            }
            Text {
                text: "[X]"
                font.family: panel.pixel; font.pixelSize: 14; color: panel.warn
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.requestClose() }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

        // ---- battery ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            visible: panel.batPct >= 0
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "BATTERY  " + panel.batPct + "%"
                    font.family: panel.pixel; font.pixelSize: 13
                    color: (panel.batPct <= 15 && panel.batStatus !== "Charging") ? panel.warn : panel.cyanB
                }
                Text {
                    text: panel.batStatus === "Charging" ? "CHARGING"
                        : (panel.batTimeMin > 0
                            ? (Math.floor(panel.batTimeMin/60) + "h " + (panel.batTimeMin%60) + "m left")
                            : panel.batStatus.toUpperCase())
                    font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD
                }
            }
            Rectangle {
                Layout.fillWidth: true; height: 14
                color: "#05080d"; border.width: 1
                border.color: (panel.batPct <= 15 && panel.batStatus !== "Charging") ? panel.warn : panel.cyanD
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(0, (parent.width - 4) * panel.batPct / 100)
                    color: panel.batStatus === "Charging" ? "#5DE285"
                         : (panel.batPct <= 15 ? panel.warn : panel.cyan)
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Text {
                text: ">_ power settings _<"
                font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.run("systemsettings kcm_powerdevilprofilesconfig") }
            }
        }

        // ---- UI sounds ----
        RowLayout {
            Layout.fillWidth: true; spacing: 5
            Text { Layout.fillWidth: true; text: "UI SOUNDS"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
            Rectangle {
                width: 74; height: 26
                color: Sfx.enabled ? panel.cyan : "transparent"
                border.color: panel.cyanD; border.width: 1
                Text { anchors.centerIn: parent; text: Sfx.enabled ? "ON" : "OFF"
                    font.family: panel.pixel; font.pixelSize: 11
                    color: Sfx.enabled ? "#04141c" : panel.cyanB }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { Sfx.enabled = !Sfx.enabled; if (Sfx.enabled) Sfx.play("menu") } }
            }
        }

        // ---- intro video ----
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 42
            color: introArea.containsMouse ? "#143245" : "#0c1620"
            border.color: panel.cyanD
            Text {
                anchors.centerIn: parent; text: ">_ INTRO VIDEO _<"
                font.family: panel.pixel; font.pixelSize: 14; color: panel.cyanB
            }
            MouseArea {
                id: introArea; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.requestIntroSettings()
            }
        }

        // ---- input devices (KDE system settings pages) ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            Text { text: "INPUT"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }

            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: [
                        { l: "MOUSE",    p: "kcm_mouse" },
                        { l: "TOUCHPAD", p: "kcm_touchpad" },
                        { l: "KEYBOARD", p: "kcm_keyboard" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 28
                        color: inMa.containsMouse ? "#143245" : "#0c1620"
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: modelData.l
                            font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanB
                        }
                        MouseArea {
                            id: inMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.run("systemsettings " + modelData.p); panel.requestClose() }
                        }
                    }
                }
            }
        }

        // ---- lid close action ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            visible: panel.hasLid          // laptops (works with the battery removed)
            Text { text: "WHEN LID CLOSES"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
            Text { text: "  applies after reboot"
                font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD }
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: [
                        { id: "suspend", label: "SLEEP"  },
                        { id: "lock",    label: "LOCK"   },
                        { id: "ignore",  label: "NOTHING"}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 26
                        readonly property bool on: panel.lidAction === modelData.id
                        color: on ? panel.cyan : (lidMa.containsMouse ? "#143245" : "transparent")
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: modelData.label
                            font.family: panel.pixel; font.pixelSize: 11
                            color: parent.on ? "#04141c" : panel.cyanB
                        }
                        MouseArea {
                            id: lidMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.lidAction = modelData.id
                                panel.run("pkexec sh -c 'mkdir -p /etc/systemd/logind.conf.d; printf \"[Login]\\nHandleLidSwitch=" + modelData.id + "\\nHandleLidSwitchExternalPower=" + modelData.id + "\\nHandleLidSwitchDocked=" + modelData.id + "\\n\" > /etc/systemd/logind.conf.d/90-index.conf'")
                            }
                        }
                    }
                }
            }
        }

        // ---- screen timeout / power profiles (KDE PowerDevil) ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "SCREEN / SLEEP / LOCK"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Rectangle {
                    Layout.fillWidth: true; height: 26
                    color: scrMa.containsMouse ? "#143245" : "#0c1620"
                    border.color: panel.cyanD; border.width: 1
                    Text {
                        anchors.centerIn: parent; text: "SCREEN / SLEEP"
                        font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanB
                    }
                    MouseArea {
                        id: scrMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.run("systemsettings kcm_powerdevilprofilesconfig"); panel.requestClose() }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 26
                    color: lockMa.containsMouse ? "#143245" : "#0c1620"
                    border.color: panel.cyanD; border.width: 1
                    Text {
                        anchors.centerIn: parent; text: "AUTO LOCK"
                        font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanB
                    }
                    MouseArea {
                        id: lockMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.run("systemsettings kcm_screenlocker"); panel.requestClose() }
                    }
                }
            }
        }

        // ---- volume slider ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "VOLUME  " + panel.volume + "%"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanD }
            Rectangle {
                Layout.fillWidth: true; height: 18
                color: "#04141c"; border.color: panel.cyanD; border.width: 1
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: (parent.width-4) * panel.volume/100
                    color: panel.cyan
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(m) {
                        panel.volume = Math.round(m.x/width*100)
                        panel.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (panel.volume/100).toFixed(2))
                    }
                    onWheel: function(w) {
                        panel.volume = Math.max(0, Math.min(100, panel.volume + (w.angleDelta.y>0?5:-5)))
                        panel.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (panel.volume/100).toFixed(2))
                    }
                }
            }
        }

        // ---- brightness slider ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "BRIGHTNESS  " + panel.brightness + "%"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanD }
            Rectangle {
                Layout.fillWidth: true; height: 18
                color: "#04141c"; border.color: panel.cyanD; border.width: 1
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: (parent.width-4) * panel.brightness/100
                    color: panel.cyanB
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: function(m) {
                        panel.brightness = Math.max(5, Math.round(m.x/width*100))
                        panel.run("brightnessctl set " + panel.brightness + "%")
                    }
                    onWheel: function(w) {
                        panel.brightness = Math.max(5, Math.min(100, panel.brightness + (w.angleDelta.y>0?5:-5)))
                        panel.run("brightnessctl set " + panel.brightness + "%")
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panel.cyanD }

        // ---- toggles / shortcuts ----
        GridLayout {
            Layout.fillWidth: true
            columns: 2; rowSpacing: 8; columnSpacing: 8

            Repeater {
                model: [
                    { t: "NETWORK",   s: panel.netName === "" ? "offline" : panel.netName,
                      c: "systemsettings kcm_networkmanagement" },
                    { t: "BLUETOOTH", s: panel.btOn ? "on" : "off",
                      c: "systemsettings kcm_bluetooth" },
                    { t: "AUDIO",     s: "mixer",   c: "systemsettings kcm_pulseaudio" },
                    { t: "DISPLAY",   s: "outputs", c: "systemsettings kcm_kscreen" },
                    { t: "FILES",     s: "manager", c: "dolphin" },
                    { t: "MUTE",      s: "toggle",  c: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 46
                    color: bma.containsMouse ? "#143245" : "#0c1620"
                    border.color: panel.cyanD; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text { anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.t
                            font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
                        Text { anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.s
                            font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD
                            elide: Text.ElideRight }
                    }
                    MouseArea {
                        id: bma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.run(modelData.c); panel.requestClose() }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ---- startup apps ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "START WITH DESKTOP"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }

            Repeater {
                model: panel.autostartApps
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "  " + modelData.name
                        font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanB
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "[REMOVE]"
                        font.family: panel.pixel; font.pixelSize: 10; color: panel.warn
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.run("rm -f \"$HOME/.config/autostart/" + modelData.file + "\"")
                                autostartGet.running = true
                            } }
                    }
                }
            }
            Text {
                visible: panel.autostartApps.length === 0
                text: "  none"
                font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD
            }
            Text {
                text: ">_ add an app _<"
                font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.run("systemsettings kcm_autostart")
                        autostartRefresh.restart()
                    } }
            }
            Timer { id: autostartRefresh; interval: 2500; repeat: false
                onTriggered: autostartGet.running = true }
        }

        // ---- printers ----
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "PRINTERS"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
            Text {
                text: ">_ manage _<"
                font.family: panel.pixel; font.pixelSize: 10; color: panel.cyanD
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.run("system-config-printer || xdg-open http://localhost:631 || true") }
            }
        }

        // ---- power row ----
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [
                    { t: "LOCK",   c: "qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock", col: panel.cyan },
                    { t: "REBOOT", c: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndReboot",  col: panel.cyanD },
                    { t: "OFF",    c: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndShutdown", col: panel.warn }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    color: pma.containsMouse ? modelData.col : "transparent"
                    border.color: modelData.col; border.width: 1
                    Text {
                        anchors.centerIn: parent; text: modelData.t
                        font.family: panel.pixel; font.pixelSize: 14
                        color: pma.containsMouse ? "#04141c" : modelData.col
                    }
                    MouseArea {
                        id: pma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.run(modelData.c); panel.requestClose() }
                    }
                }
            }
        }
    }
}
