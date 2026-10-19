// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  quick settings (Win+A)
//  Windows 11-style flyout under the bar's right edge:
//  toggle tiles (wifi, bluetooth, night light, do-not-disturb,
//  airplane, mic), volume + brightness sliders, battery and
//  settings / lock / power in the footer.
//  Open state lives in UiState.quickSettingsOpen (bar button,
//  KWin shortcut). Commands mirror Settings.qml / SettingsPanel.qml.
//  States are polled only while the panel is open.
// ============================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "."

Scope {
    id: quick

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"

    readonly property bool open: UiState.quickSettingsOpen

    // ---- live system state (refreshed by the pollers below) ----
    property bool hasWifi: false
    property bool hasWwan: false
    property bool wwanOn: false
    property bool wifiOn: false
    property string wifiSsid: ""
    property bool hasBt: false
    property bool btOn: false
    property string btDevice: ""
    property bool nightOn: false
    readonly property bool hasRadio: hasWifi || hasWwan || hasBt
    readonly property bool airplaneOn: hasRadio && (!hasWifi || !wifiOn)
        && (!hasWwan || !wwanOn) && (!hasBt || !btOn)
    property bool micMutedCli: false       // fallback when PipeWire has no default source
    property bool hasBacklight: false
    property int  bright: 70
    property int  batPct: -1
    property string batStatus: ""

    // PipeWire: default sink (volume) and source (mic)
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var srcAudio:  Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    readonly property int  vol: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
    readonly property bool volMuted: sinkAudio ? sinkAudio.muted : false
    readonly property bool micMuted: srcAudio ? srcAudio.muted : micMutedCli

    function sh(c) { Quickshell.execDetached(["sh","-c",c]) }
    function close() { UiState.quickSettingsOpen = false }

    function refresh(): void {
        wifiGet.running = true; btGet.running = true; nightGet.running = true
        airGet.running = true; briGet.running = true; batGet.running = true
        if (!quick.srcAudio) micGet.running = true
    }

    // ---- pollers ----
    Process {
        id: wifiGet
        // Radio state, SSID (possibly empty), then actual device types.
        command: ["sh","-c","nmcli radio wifi 2>/dev/null; ssid=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | grep -m1 '^wifi:connected:' | cut -d: -f3-); printf '%s\\n' \"$ssid\"; nmcli -t -f TYPE device 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var l = text.split("\n")
            var types = l.slice(2).map(function(t) { return t.trim() })
            quick.hasWifi = types.indexOf("wifi") >= 0
            quick.hasWwan = types.indexOf("gsm") >= 0 || types.indexOf("cdma") >= 0 || types.indexOf("wwan") >= 0
            quick.wifiOn = quick.hasWifi && (l[0] || "").trim() === "enabled"
            quick.wifiSsid = Glyph.clean((l[1] || "").trim())
        } }
    }
    Process {
        id: btGet
        command: ["sh","-c","[ -d /sys/class/bluetooth ] || exit 0; info=$(LC_ALL=C timeout -k 1 2 bluetoothctl show 2>/dev/null); a=0; p=0; printf '%s\\n' \"$info\" | grep -q '^Controller ' && a=1; printf '%s\\n' \"$info\" | grep -q 'Powered: yes' && p=1; printf '%s|%s|%s' \"$a\" \"$p\" \"$(timeout -k 1 2 bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)\""]
        stdout: StdioCollector { onStreamFinished: {
            var f = text.trim().split("|")
            quick.hasBt = f[0] === "1"
            quick.btOn = quick.hasBt && f[1] === "1"
            quick.btDevice = Glyph.clean(f.slice(2).join("|").trim())
        } }
    }
    Process {
        id: nightGet
        command: ["sh","-c","kreadconfig6 --file kwinrc --group NightColor --key Active 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: quick.nightOn = (text.trim() === "true") }
    }
    Process {
        id: airGet
        // terse: WIFI-HW:WIFI:WWAN-HW:WWAN; Wi-Fi is read by wifiGet.
        command: ["sh","-c","nmcli -t radio all 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var f = text.trim().split(":")
            quick.wwanOn = f.length >= 4 && f[3] === "enabled"
        } }
    }
    Process {
        id: micGet
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: quick.micMutedCli = (text.trim() === "1") }
    }
    Process {
        id: briGet
        command: ["sh","-c","ls /sys/class/backlight/* >/dev/null 2>&1 || { echo -1; exit 0; }; brightnessctl -m -c backlight 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector { onStreamFinished: {
            var v = parseInt(text.trim())
            quick.hasBacklight = !isNaN(v) && v >= 0
            if (quick.hasBacklight) quick.bright = v
        } }
    }
    Process {
        id: batGet
        command: ["sh","-c","c=/sys/class/power_supply/BAT0; [ -d $c ] || c=/sys/class/power_supply/BAT1; if [ -d $c ]; then printf '%s|%s' \"$(cat $c/capacity)\" \"$(cat $c/status)\"; else printf -- '-1|none'; fi"]
        stdout: StdioCollector { onStreamFinished: {
            var f = text.trim().split("|")
            var v = parseInt(f[0]); quick.batPct = isNaN(v) ? -1 : v
            quick.batStatus = f[1] || ""
        } }
    }
    Timer {
        // triggeredOnStart = a fresh read every time the panel opens
        interval: 3000; running: UiState.quickSettingsOpen; repeat: true; triggeredOnStart: true
        onTriggered: quick.refresh()
    }
    // re-read shortly after a toggle so the tile shows the real result
    Timer { id: settle; interval: 1500; repeat: false; onTriggered: if (quick.open) quick.refresh() }

    // ---- actions ----
    function tileAvailable(key) {
        if (key === "wifi") return quick.hasWifi
        if (key === "bt") return quick.hasBt
        if (key === "air") return quick.hasRadio
        if (key === "mic") return !!quick.srcAudio
        return true
    }
    function toggle(key) {
        if (!quick.tileAvailable(key)) return
        if (key === "wifi") {
            quick.wifiOn = !quick.wifiOn
            quick.sh("nmcli radio wifi " + (quick.wifiOn ? "on" : "off"))
        } else if (key === "bt") {
            quick.btOn = !quick.btOn
            quick.sh("bluetoothctl power " + (quick.btOn ? "on" : "off"))
        } else if (key === "night") {
            quick.nightOn = !quick.nightOn
            // KWin's own Night Light (constant 3500K while on), same as Settings.qml
            quick.sh("kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant; "
                + "kwriteconfig6 --file kwinrc --group NightColor --key NightTemperature 3500; "
                + "kwriteconfig6 --file kwinrc --group NightColor --key Active --notify "
                + (quick.nightOn ? "true" : "false")
                + "; qdbus6 org.kde.KWin /KWin reconfigure")
        } else if (key === "dnd") {
            UiState.doNotDisturb = !UiState.doNotDisturb
        } else if (key === "air") {
            var radiosOn = quick.airplaneOn
            var commands = []
            if (quick.hasWifi || quick.hasWwan) commands.push("nmcli radio all " + (radiosOn ? "on" : "off"))
            if (quick.hasBt) commands.push("bluetoothctl power " + (radiosOn ? "on" : "off"))
            quick.wifiOn = quick.hasWifi && radiosOn
            quick.wwanOn = quick.hasWwan && radiosOn
            quick.btOn = quick.hasBt && radiosOn
            quick.sh(commands.join("; "))
        } else if (key === "mic") {
            if (quick.srcAudio) quick.srcAudio.muted = !quick.srcAudio.muted
            else { quick.micMutedCli = !quick.micMutedCli; quick.sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") }
        }
        Sfx.play("tick")
        settle.restart()
    }
    function tileOn(key) {
        if (!quick.tileAvailable(key)) return false
        return key === "wifi"  ? quick.wifiOn
             : key === "bt"    ? quick.btOn
             : key === "night" ? quick.nightOn
             : key === "dnd"   ? UiState.doNotDisturb
             : key === "air"   ? quick.airplaneOn
             : key === "mic"   ? quick.micMuted
             : false
    }
    function tileStatus(key) {
        if (!quick.tileAvailable(key)) return key === "mic" ? "no input" : "no adapter"
        if (key === "wifi")  return !quick.wifiOn ? "off" : (quick.wifiSsid !== "" ? quick.wifiSsid : "not connected")
        if (key === "bt")    return !quick.btOn ? "off" : (quick.btDevice !== "" ? quick.btDevice : "on")
        if (key === "night") return quick.nightOn ? "3500K" : "off"
        if (key === "dnd")   return UiState.doNotDisturb ? "silenced" : "off"
        if (key === "air")   return quick.airplaneOn ? "on" : "off"
        if (key === "mic")   return quick.micMuted ? "muted" : "live"
        return ""
    }
    function setVolume(x, w) {
        if (!quick.sinkAudio) return
        quick.sinkAudio.muted = false
        quick.sinkAudio.volume = Math.max(0, Math.min(1, x / w))
    }
    function setBright(x, w) {
        quick.bright = Math.max(5, Math.min(100, Math.round(x / w * 100)))
        quick.sh("brightnessctl -c backlight set " + quick.bright + "%")
    }

    // click anywhere outside the panel to close it
    PanelWindow {
        screen: Screens.main
        id: qsDismiss
        visible: UiState.quickSettingsOpen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "index-quick-dismiss"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: quick.close()
        }
    }

    // ===================== PANEL =====================
    PanelWindow {
        screen: Screens.main
        id: qsWin
        visible: UiState.quickSettingsOpen
        anchors { top: true; right: true }
        margins { top: 32; right: 8 }
        implicitWidth: 360
        implicitHeight: body.implicitHeight + 28
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "index-quick-settings"
        onVisibleChanged: if (visible) frame.forceActiveFocus()

        Rectangle {
            id: frame
            anchors.fill: parent
            color: "#05080d"
            border.color: quick.cyan
            border.width: 2
            focus: true
            Keys.onEscapePressed: quick.close()
            opacity: UiState.quickSettingsOpen ? 1 : 0
            transform: Translate { y: UiState.quickSettingsOpen ? 0 : -18
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                id: body
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                spacing: 12

                // header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: ">_ QUICK SETTINGS_"
                        font.family: quick.pixel; font.pixelSize: 17; color: quick.cyanB
                    }
                    Text {
                        text: "[X]"
                        font.family: quick.pixel; font.pixelSize: 14; color: quick.warn
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: quick.close() }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: quick.cyanD }

                // ---------- TOGGLE TILES ----------
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3; rowSpacing: 8; columnSpacing: 8

                    Repeater {
                        model: [
                            { key: "wifi",  label: "WI-FI",          kcm: "kcm_networkmanagement" },
                            { key: "bt",    label: "BLUETOOTH",      kcm: "kcm_bluetooth" },
                            { key: "night", label: "NIGHT LIGHT",    kcm: "" },
                            { key: "dnd",   label: "DO NOT DISTURB", kcm: "" },
                            { key: "air",   label: "AIRPLANE",       kcm: "" },
                            { key: "mic",   label: "MIC MUTE",       kcm: "" }
                        ]
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            readonly property bool on: quick.tileOn(modelData.key)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1          // equal thirds
                            implicitHeight: 52
                            color: on ? quick.cyan : (tileMa.containsMouse ? "#143245" : "#0c1620")
                            border.color: on ? quick.cyanB : quick.cyanD
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Column {
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                spacing: 3
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: tile.modelData.label
                                    font.family: quick.pixel; font.pixelSize: 11
                                    color: tile.on ? "#04141c" : quick.cyanB
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: quick.tileStatus(tile.modelData.key)
                                    font.family: quick.pixel; font.pixelSize: 10
                                    color: tile.on ? "#0c2a3a" : quick.cyanD
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: tileMa
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(m) {
                                    if (m.button === Qt.RightButton) {
                                        if (tile.modelData.kcm !== "") {
                                            quick.sh("systemsettings " + tile.modelData.kcm)
                                            quick.close()
                                        }
                                        return
                                    }
                                    quick.toggle(tile.modelData.key)
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: quick.cyanD }

                // ---------- VOLUME ----------
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: !quick.sinkAudio ? "VOLUME  --" : quick.volMuted ? "VOLUME  MUTE" : "VOLUME  " + quick.vol + "%"
                            font.family: quick.pixel; font.pixelSize: 13
                            color: quick.volMuted ? quick.warn : quick.cyanB
                        }
                        // mute toggle "icon"
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 20
                            color: quick.volMuted ? quick.warn : (muteMa.containsMouse ? "#143245" : "transparent")
                            border.color: quick.volMuted ? quick.warn : quick.cyanD; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: quick.volMuted ? "<|x" : "<|)"
                                font.family: quick.pixel; font.pixelSize: 12
                                color: quick.volMuted ? "#04141c" : quick.cyanB
                            }
                            MouseArea {
                                id: muteMa
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (quick.sinkAudio) quick.sinkAudio.muted = !quick.sinkAudio.muted
                            }
                        }
                    }
                    Rectangle {
                        id: volTrack
                        Layout.fillWidth: true; height: 18
                        color: "#05080d"; border.color: quick.cyanD; border.width: 1
                        opacity: quick.sinkAudio ? 1 : 0.4
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: Math.max(0, (parent.width - 4) * Math.min(100, quick.vol) / 100)
                            color: quick.volMuted ? quick.cyanD : quick.cyan
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(m) { quick.setVolume(m.x, volTrack.width) }
                            onPositionChanged: function(m) { if (pressed) quick.setVolume(m.x, volTrack.width) }
                            onWheel: function(w) {
                                if (!quick.sinkAudio) return
                                quick.sinkAudio.muted = false
                                quick.sinkAudio.volume = Math.max(0, Math.min(1, quick.sinkAudio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
                            }
                        }
                    }
                }

                // ---------- BRIGHTNESS (only with a backlight) ----------
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    visible: quick.hasBacklight
                    Text {
                        text: "BRIGHTNESS  " + quick.bright + "%"
                        font.family: quick.pixel; font.pixelSize: 13; color: quick.cyanB
                    }
                    Rectangle {
                        id: brTrack
                        Layout.fillWidth: true; height: 18
                        color: "#05080d"; border.color: quick.cyanD; border.width: 1
                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: Math.max(0, (parent.width - 4) * quick.bright / 100)
                            color: quick.cyanB
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(m) { quick.setBright(m.x, brTrack.width) }
                            onPositionChanged: function(m) { if (pressed) quick.setBright(m.x, brTrack.width) }
                            onWheel: function(w) {
                                quick.bright = Math.max(5, Math.min(100, quick.bright + (w.angleDelta.y > 0 ? 5 : -5)))
                                quick.sh("brightnessctl -c backlight set " + quick.bright + "%")
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: quick.cyanD }

                // ---------- FOOTER: battery + settings / lock / power ----------
                RowLayout {
                    Layout.fillWidth: true; spacing: 6

                    Text {
                        visible: quick.batPct >= 0
                        text: "BAT " + quick.batPct + "%" + (quick.batStatus === "Charging" ? "+" : "")
                        font.family: quick.pixel; font.pixelSize: 13
                        color: (quick.batPct <= 15 && quick.batStatus !== "Charging") ? quick.warn : quick.cyanB
                    }
                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { t: "SETTINGS", c: "systemsettings", col: quick.cyanB },
                            { t: "LOCK",     c: "qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock", col: quick.cyan },
                            // Always request KDE's chooser; a failed prompt must not shut down.
                            { t: "POWER",    c: "qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptAll", col: quick.warn }
                        ]
                        delegate: Rectangle {
                            id: footBtn
                            required property var modelData
                            implicitWidth: footTxt.implicitWidth + 14
                            implicitHeight: 28
                            color: footMa.containsMouse ? modelData.col : "transparent"
                            border.color: modelData.col; border.width: 1
                            Text {
                                id: footTxt
                                anchors.centerIn: parent; text: footBtn.modelData.t
                                font.family: quick.pixel; font.pixelSize: 12
                                color: footMa.containsMouse ? "#04141c" : footBtn.modelData.col
                            }
                            MouseArea {
                                id: footMa
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (footBtn.modelData.t === "SETTINGS") UiState.openSettings()
                                    else { quick.sh(footBtn.modelData.c); quick.close() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
