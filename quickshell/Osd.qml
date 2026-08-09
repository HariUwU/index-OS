// WILL OF THE CITY :: THE INDEX  —  volume / brightness OSD
// Watches the sink volume and backlight, shows a brief centred bar on change.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

PanelWindow {
    id: osd
    anchors { bottom: true }
    margins { bottom: 120 }
    implicitWidth: 320
    implicitHeight: 74
    color: "transparent"
    exclusiveZone: 0
    visible: shown
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "index-osd"

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    property bool shown: false
    property string kind: "VOL"
    property int value: 0
    property bool muted: false
    property bool primed: false        // skip the very first poll

    function flash(k, v, m) {
        kind = k; value = v; muted = m || false
        if (!primed) return            // don't pop up on startup
        Sfx.play("tick")
        shown = true
        hideTimer.restart()
    }

    Timer { id: hideTimer; interval: 1400; repeat: false; onTriggered: osd.shown = false }

    // ---- pollers ----
    property int lastVol: -1
    property bool lastMuted: false
    Process {
        id: volGet
        command: ["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var t = text.trim()
            if (t === "") return
            var m = t.match(/([0-9.]+)/)
            if (!m) return
            var v = Math.round(parseFloat(m[1]) * 100)
            var mu = t.indexOf("MUTED") >= 0
            if (v !== osd.lastVol || mu !== osd.lastMuted) {
                osd.lastVol = v; osd.lastMuted = mu
                osd.flash("VOL", v, mu)
            }
        } }
    }
    property int lastBri: -1
    Process {
        id: briGet
        command: ["sh","-c","brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector { onStreamFinished: {
            var v = parseInt(text.trim())
            if (isNaN(v)) return
            if (v !== osd.lastBri) {
                osd.lastBri = v
                osd.flash("BRIGHT", v, false)
            }
        } }
    }
    Timer {
        interval: 250; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { volGet.running = true; briGet.running = true }
    }
    Timer { interval: 1500; running: true; repeat: false; onTriggered: osd.primed = true }

    // ---- UI ----
    Rectangle {
        anchors.fill: parent
        color: "#0a0e16"
        border.color: "#5DADE2"
        border.width: 2
        opacity: osd.shown ? 0.96 : 0.0
        scale: osd.shown ? 1.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        Text {
            id: osdLabel
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.top: parent.top; anchors.topMargin: 10
            text: osd.muted ? "VOL  MUTE" : (osd.kind + "  " + osd.value + "%")
            font.family: osd.pixel; font.pixelSize: 15
            color: osd.muted ? "#FF6B6B" : "#85C5E8"
        }

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 14
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            height: 16
            color: "#05080d"
            border.color: "#3A7CA5"; border.width: 1
            Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.margins: 2
                width: Math.max(0, (parent.width - 4) * (osd.muted ? 0 : osd.value) / 100)
                color: osd.kind === "BRIGHT" ? "#85C5E8" : "#5DADE2"
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
    }
}
