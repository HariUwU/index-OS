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
    property int  screenOffMin: 10           // 0 = never
    property real pointerSpeed: 0.0          // -1.0 .. 1.0
    property bool naturalScroll: false
    property bool tapClick: true
    property int  cursorSize: 24
    property bool inputLoaded: false
    property bool hasLid: false
    property var autostartApps: []

    // Build one locked, atomic config write.
    // The old version launched several detached read/temp/move jobs at once, so
    // two quick setting changes could overwrite each other.
    function confWriteCommand(pairs) {
        var filter = "", adds = ""
        for (var i = 0; i < pairs.length; i++) {
            var k = pairs[i][0], v = pairs[i][1]
            filter += " | grep -v '^" + k + "='"
            adds   += "printf '%s\\n' '" + k + "=" + v + "' >> \"$t\"; "
        }

        return "mkdir -p \"$HOME/.config/labwc\"; " +
               "f=\"$HOME/.config/labwc/index.conf\"; lock=\"$f.lock\"; " +
               "( flock -x 9; " +
               "touch \"$f\"; t=$(mktemp \"$f.tmp.XXXXXX\") || exit 1; " +
               "cat \"$f\"" + filter + " > \"$t\" 2>/dev/null; " +
               adds +
               "tac \"$t\" | awk -F= '!seen[$1]++' | tac > \"$t.d\" 2>/dev/null && mv \"$t.d\" \"$t\"; " +
               "mv -f \"$t\" \"$f\"; " +
               ") 9>\"$lock\""
    }

    function saveConf(pairs) {
        panel.run(panel.confWriteCommand(pairs))
    }

    function applyInput(): void {
        var cmd = panel.confWriteCommand([
            ["POINTER_SPEED", panel.pointerSpeed.toFixed(2)],
            ["NATURAL_SCROLL", panel.naturalScroll ? "yes" : "no"],
            ["TAP_CLICK", panel.tapClick ? "yes" : "no"]
        ])
        // Save first, then apply from that exact saved file in the SAME process.
        panel.run(cmd + "; sh \"$HOME/.config/labwc/index-input\"; pkill -HUP labwc"); panel.refreshSavedSoon()
    }

    function applyCursor(): void {
        var cmd = panel.confWriteCommand([["CURSOR_SIZE", panel.cursorSize]])
        panel.run(cmd + "; sh \"$HOME/.config/labwc/index-input\"; pkill -HUP labwc")
    }

    signal requestClose()

    function run(cmd) { Quickshell.execDetached(["sh","-c",cmd]) }

    // Re-read saved values shortly after a write finishes so the panel UI
    // immediately reflects what is actually stored in index.conf.
    function refreshSavedSoon(): void {
        savedRefresh.restart()
    }

    Timer {
        id: savedRefresh
        interval: 250
        repeat: false
        onTriggered: {
            inputGet.running = true
            idleGet.running = true
        }
    }

    // pull fresh values every time the panel appears
    onVisibleChanged: if (visible) panel.refresh()
    Component.onCompleted: panel.refresh()
    function refresh(): void {
        volGet.running=true; briGet.running=true; btGet.running=true; netGet.running=true
        batGet.running=true; batTimeGet.running=true; lidGet.running=true; lidDetect.running=true
        autostartGet.running=true; idleGet.running=true; inputGet.running=true
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
        command: ["sh","-c","bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
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
        id: inputGet
        command: ["sh","-c","f=$HOME/.config/labwc/index.conf; " +
                  "ps=$(sed -n 's|^POINTER_SPEED=||p' $f 2>/dev/null | tail -1); " +
                  "ns=$(sed -n 's|^NATURAL_SCROLL=||p' $f 2>/dev/null | tail -1); " +
                  "tp=$(sed -n 's|^TAP_CLICK=||p' $f 2>/dev/null | tail -1); " +
                  "cs=$(sed -n 's|^CURSOR_SIZE=||p' $f 2>/dev/null | tail -1); " +
                  "printf '%s|%s|%s|%s' \"$ps\" \"$ns\" \"$tp\" \"$cs\""]
        stdout: StdioCollector { onStreamFinished: {
            var f = text.trim().split("|")
            var v = parseFloat(f[0]); if (!isNaN(v)) panel.pointerSpeed = v
            if (f[1]) panel.naturalScroll = (f[1] === "yes")
            if (f[2]) panel.tapClick      = (f[2] === "yes")
            var c = parseInt(f[3]); if (!isNaN(c)) panel.cursorSize = c
        } }
    }

    Process {
        id: idleGet
        command: ["sh","-c","f=$HOME/.config/labwc/index.conf; [ -f $f ] && sed -n 's|^SCREEN_OFF_SEC=||p' $f | tail -1 || echo 600"]
        stdout: StdioCollector { onStreamFinished: {
            var v = parseInt(text.trim())
            if (!isNaN(v)) panel.screenOffMin = Math.round(v / 60)
        } }
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
                    onClicked: panel.run("xfce4-power-manager-settings || gnome-power-statistics || true") }
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

        // ---- mouse / touchpad ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 6

            Text { text: "MOUSE"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }

            // pointer speed
            Text { text: "  speed  " + panel.pointerSpeed.toFixed(2)
                font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD }
            Rectangle {
                Layout.fillWidth: true; height: 16
                color: "#05080d"; border.color: panel.cyanD; border.width: 1
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4
                    width: Math.max(2, (parent.width - 4) * ((panel.pointerSpeed + 1) / 2))
                    color: panel.cyan
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function setFromX(mx) {
                        var f = Math.max(0, Math.min(1, mx / width))
                        panel.pointerSpeed = Math.round((f * 2 - 1) * 100) / 100
                    }
                    onPressed: function(m) { setFromX(m.x) }
                    onPositionChanged: function(m) { if (pressed) setFromX(m.x) }
                    onReleased: panel.applyInput()
                }
            }

            // cursor size
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Text { text: "  cursor"
                    font.family: panel.pixel; font.pixelSize: 11; color: panel.cyanD }
                Repeater {
                    model: [16, 24, 32, 48]
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true; height: 24
                        readonly property bool on: panel.cursorSize === modelData
                        color: on ? panel.cyan : (curMa.containsMouse ? "#143245" : "transparent")
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: modelData
                            font.family: panel.pixel; font.pixelSize: 11
                            color: parent.on ? "#04141c" : panel.cyanB
                        }
                        MouseArea {
                            id: curMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.cursorSize = modelData; panel.applyCursor() }
                        }
                    }
                }
            }

            // toggles
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: [
                        { key: "scroll", label: "NATURAL SCROLL" },
                        { key: "tap",    label: "TAP TO CLICK"   }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 28
                        readonly property bool on: modelData.key === "scroll" ? panel.naturalScroll : panel.tapClick
                        color: on ? panel.cyan : (tglMa.containsMouse ? "#143245" : "transparent")
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label + (parent.on ? "  ON" : "  OFF")
                            font.family: panel.pixel; font.pixelSize: 10
                            color: parent.on ? "#04141c" : panel.cyanB
                        }
                        MouseArea {
                            id: tglMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.key === "scroll") panel.naturalScroll = !panel.naturalScroll
                                else panel.tapClick = !panel.tapClick
                                panel.applyInput()
                            }
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

        // ---- screen timeout ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { text: "SCREEN OFF AFTER"
                font.family: panel.pixel; font.pixelSize: 13; color: panel.cyanB }
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: [ {m:1,l:"1m"}, {m:5,l:"5m"}, {m:10,l:"10m"}, {m:30,l:"30m"}, {m:0,l:"NEVER"} ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 26
                        readonly property bool on: panel.screenOffMin === modelData.m
                        color: on ? panel.cyan : (scrMa.containsMouse ? "#143245" : "transparent")
                        border.color: panel.cyanD; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: modelData.l
                            font.family: panel.pixel; font.pixelSize: 11
                            color: parent.on ? "#04141c" : panel.cyanB
                        }
                        MouseArea {
                            id: scrMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.screenOffMin = modelData.m
                                // SAVE it, then restart the idle daemon from the saved value
                                var cmd = panel.confWriteCommand([["SCREEN_OFF_SEC", (modelData.m * 60)]])
                                panel.run(cmd + "; setsid sh \"$HOME/.config/labwc/index-idle\" >/dev/null 2>&1 &"); panel.refreshSavedSoon()
                            }
                        }
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
                        panel.run("brightnessctl set " + panel.brightness + "%; " + panel.confWriteCommand([["BRIGHTNESS", panel.brightness]]))
                    }
                    onWheel: function(w) {
                        panel.brightness = Math.max(5, Math.min(100, panel.brightness + (w.angleDelta.y>0?5:-5)))
                        panel.run("brightnessctl set " + panel.brightness + "%; " + panel.confWriteCommand([["BRIGHTNESS", panel.brightness]]))
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
                      c: "nm-connection-editor || iwgtk" },
                    { t: "BLUETOOTH", s: panel.btOn ? "on" : "off",
                      c: "blueman-manager || blueberry" },
                    { t: "AUDIO",     s: "mixer",   c: "pavucontrol" },
                    { t: "DISPLAY",   s: "outputs", c: "wdisplays || wlr-randr" },
                    { t: "FILES",     s: "manager", c: "thunar" },
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
                        // pick any installed .desktop with wofi, copy it into ~/.config/autostart
                        panel.run("f=$(ls /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop 2>/dev/null | xargs -n1 basename | sort -u | wofi --dmenu -p 'start at login'); [ -n \"$f\" ] && { mkdir -p ~/.config/autostart; cp -f \"$(ls /usr/share/applications/$f ~/.local/share/applications/$f 2>/dev/null | head -1)\" ~/.config/autostart/; }")
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
                    { t: "LOCK",   c: "$HOME/.config/labwc/index-lock", col: panel.cyan },
                    { t: "REBOOT", c: "systemctl reboot",  col: panel.cyanD },
                    { t: "OFF",    c: "systemctl poweroff", col: panel.warn }
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
