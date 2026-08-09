// WILL OF THE CITY :: THE INDEX  —  UI sound effects (singleton)
// Plays short wavs through pw-play (SoundEffect is unreliable on layer shells).
// Drop your own files in assets/sounds/ui/ to override the defaults.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool enabled: true
    // stay silent while the lock is up (boot, or a manual lock)
    property bool locked: true
    // set briefly by DeviceWatch so its own notify-send doesn't double-chime
    property bool muteNotify: false
    property real volume: 0.6

    readonly property string uiDir:  Qt.resolvedUrl("assets/sounds/ui/").toString().replace("file://", "")
    readonly property string lockDir: Qt.resolvedUrl("lock/assets/sounds/").toString().replace("file://", "")

    // name -> preferred file, with a fallback to the lock's existing wavs
    readonly property var map: ({
        "notify":     ["notify.wav",     "check.wav"],
        "tick":       ["tick.wav",       "click.wav"],
        "connect":    ["connect.wav",    "success.wav"],
        "disconnect": ["disconnect.wav", "fail.wav"],
        "menu":       ["menu.wav",       "click.wav"],
        "error":      ["error.wav",      "fail.wav"],
        "scramble":   ["scramble.mp3",   "check.wav"]
    })

    Process {
        id: lockProbe
        command: ["sh","-c","pgrep -f '[l]ock/lock.qml' >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.locked = (text.trim() === "1") }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: lockProbe.running = true
    }

    function play(name) {
        if (!root.enabled) return
        if (root.locked) return
        if (name === "notify" && root.muteNotify) return
        var e = root.map[name]
        if (!e) return
        var a = root.uiDir + e[0]        // your file, if present
        var b = root.lockDir + e[1]      // fallback
        var vol = root.volume.toFixed(2)
        Quickshell.execDetached(["sh","-c",
            "f='" + a + "'; [ -f \"$f\" ] || f='" + b + "'; [ -f \"$f\" ] || exit 0; " +
            "pw-play --volume=" + vol + " \"$f\" 2>/dev/null || paplay \"$f\" 2>/dev/null || aplay -q \"$f\" 2>/dev/null &"])
    }
}
