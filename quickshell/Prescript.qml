// WILL OF THE CITY :: THE INDEX  —  PRESCRIPT OF THE DAY (desktop widget)
// Sits on the wallpaper layer. Generates one prescript per day and keeps it
// until the date changes. Word banks come from a LOCAL prescript.json
// (see tools/prescript-convert.py) — not shipped in the repo.
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: pres
    anchors { top: true; right: true }
    margins { top: 70; right: 28 }
    implicitWidth: 420
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom          // above wallpaper, under windows
    WlrLayershell.namespace: "index-prescript"

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"

    property var bank: ({})
    property string text_: ""
    property string dateKey: ""
    property string shown: ""

    // ---- scramble reveal (same idea as the lock screen) ----
    readonly property string scrambleChars: "!<>-_\\/[]{}—=+*^?#________ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    property real scrambleTime: 0.7      // seconds of pure noise
    property real revealTime:   1.6      // seconds to resolve left-to-right
    property real elapsed: 0

    MediaPlayer {
        id: scrambleAudio
        source: Qt.resolvedUrl("assets/sounds/ui/scramble.mp3")
        loops: 1                       // one shot, no loop
        audioOutput: AudioOutput { id: scrambleOut; volume: 0.55 }
    }

    function randomChar() {
        return pres.scrambleChars.charAt(Math.floor(Math.random() * pres.scrambleChars.length))
    }
    function startScramble() {
        pres.elapsed = 0
        pres.shown = ""
        if (pres.text_ === "") return
        // Use the global SFX gate: silent while the login/session lock is active.
        Sfx.play("scramble")
        scrambler.start()
    }
    Timer {
        id: scrambler
        interval: 45; repeat: true; running: false
        onTriggered: {
            pres.elapsed += interval / 1000
            var t = pres.text_
            var out = ""
            if (pres.elapsed < pres.scrambleTime) {
                for (var i = 0; i < t.length; i++)
                    out += (t.charAt(i) === " ") ? " " : pres.randomChar()
                pres.shown = out
                return
            }
            var progress = Math.min((pres.elapsed - pres.scrambleTime) / pres.revealTime, 1)
            var revealCount = Math.floor(progress * t.length)
            for (var j = 0; j < t.length; j++)
                out += (j < revealCount || t.charAt(j) === " ") ? t.charAt(j) : pres.randomChar()
            pres.shown = out
            if (progress >= 1) {
                pres.shown = t
                scrambler.stop()
            }
        }
    }
    onText_Changed: pres.startScramble()

    function pick(name, fallback) {
        var a = pres.bank[name]
        if (!a || a.length === 0) return fallback || ""
        return a[Math.floor(Math.random() * a.length)]
    }

    // Entries are templates like "walk up to {howtofind}" — fill the slots,
    // recursively, since some filled values contain slots of their own.
    function clean(t) {
        if (!t) return ""
        return t.replace(/\s+/g, " ")
                .replace(/\s+([,.;:!?])/g, "$1")
                .replace(/([a-z])([A-Z])/g, "$1 $2")
                .trim()
    }
    function cap(t) {
        t = clean(t)
        return t === "" ? "" : t.charAt(0).toUpperCase() + t.slice(1)
    }
    function fill(t, depth) {
        if (!t) return ""
        if (depth === undefined) depth = 0
        if (depth > 4) return t.replace(/\{[^}]*\}/g, "")
        var self = pres
        return t.replace(/\{([a-zA-Z0-9_]+)\}/g, function (m, name) {
            var v = self.pick(name, "")
            return v === "" ? "" : self.fill(v, depth + 1)
        })
    }
    function compose() {
        var t0 = fill(pick("task0", ""))
        var st = fill(pick("starter", ""))
        var t1 = fill(pick("task1", "walk somewhere"))
        var tr = fill(pick("transition", ""))
        var fu = fill(pick("followup", ""))

        var out = ""
        if (Math.random() < 0.5 && t0 !== "") out = clean(t0)
        if (Math.random() < 0.3 && st !== "") out = clean(out + " " + st)
        out = clean(out + " " + t1)
        if (tr !== "" && fu !== "" && Math.random() < 0.7)
            out = clean(out + tr + " " + fu)

        out = cap(out)
        if (!/[.!?]$/.test(out)) out += "."

        if (Math.random() < 0.45) {
            var f2 = cap(fill(pick("follow2up", "")))
            if (f2 !== "") {
                if (!/[.!?]$/.test(f2)) f2 += "."
                out += " " + f2
            }
        }
        return clean(out)
    }

    function todayKey() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd") }

    function regenerateIfNeeded() {
        if (pres.dateKey === pres.todayKey() && pres.text_ !== "") return
        pres.dateKey = pres.todayKey()
        pres.text_ = pres.compose()
        saveProc.command = ["sh","-c",
            "mkdir -p $HOME/.cache; printf '%s\\n%s' " +
            "'" + pres.dateKey + "' " +
            "\"$(cat <<'EOF'\n" + pres.text_ + "\nEOF\n)\" > $HOME/.cache/index-prescript"]
        saveProc.running = true
    }
    Process { id: saveProc; command: ["true"] }

    // load today's cached prescript (so it survives a shell restart)
    Process {
        id: loadProc
        command: ["sh","-c","cat $HOME/.cache/index-prescript 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.split("\n")
            if (lines.length >= 2) {
                pres.dateKey = lines[0].trim()
                pres.text_ = lines.slice(1).join(" ").trim()
            }
            pres.regenerateIfNeeded()
        } }
    }

    // word banks
    Process {
        id: bankProc
        command: ["sh","-c","cat $HOME/.config/quickshell/prescript.json 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var t = text.trim()
            if (t === "") { pres.bank = ({}); loadProc.running = true; return }
            try { pres.bank = JSON.parse(t) } catch (e) { pres.bank = ({}) }
            loadProc.running = true
        } }
    }

    Component.onCompleted: bankProc.running = true
    // roll over at midnight
    Timer { interval: 60000; running: true; repeat: true
        onTriggered: pres.regenerateIfNeeded() }

    Rectangle {
        id: card
        anchors.left: parent.left; anchors.right: parent.right
        implicitHeight: col.implicitHeight + 26
        color: "#0a0e16"
        opacity: 0.0
        Component.onCompleted: opacity = 0.88
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
        border.color: pres.cyan
        border.width: 2

        Column {
            id: col
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 13
            spacing: 6

            Text {
                text: ">_ PRESCRIPT OF THE DAY_"
                font.family: pres.pixel; font.pixelSize: 14
                color: pres.cyanD
            }
            Rectangle { width: col.width; height: 1; color: pres.cyanD; opacity: 0.5 }
            Text {
                id: presText
                width: col.width
                text: pres.text_ === ""
                      ? "no prescript data — check prescript.json"
                      : pres.shown
                font.family: pres.pixel; font.pixelSize: 15
                color: pres.cyanB
                wrapMode: Text.WordWrap
                lineHeight: 1.15
            }
            Text {
                text: "// " + pres.dateKey + "   \u00b7   click to reroll"
                font.family: pres.pixel; font.pixelSize: 10
                color: pres.cyanD
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { pres.text_ = pres.compose(); pres.dateKey = pres.todayKey() }
        }
    }
}
