// WILL OF THE CITY :: THE INDEX  —  device watcher
// Plays connect/disconnect cues for USB storage, Bluetooth devices,
// audio sinks (headphones) and the charger. Silent for the first poll
// so plugging nothing in at login doesn't make noise.
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: dev

    property bool primed: false          // skip the first round of results
    // while the lock is up, keep re-priming so unlocking doesn't dump a burst
    property bool unlocked: !Sfx.locked
    onUnlockedChanged: if (!unlocked) { dev.primed = false; dev.pending = 4 }
    property int  pending: 4             // how many probes still to prime

    Timer { id: unmute; interval: 1200; repeat: false; onTriggered: Sfx.muteNotify = false }

    function notify(title, body) {
        Sfx.muteNotify = true; unmute.restart()
        Quickshell.execDetached(["sh","-c",
            "notify-send -a 'THE INDEX :: DEVICE' " +
            "\"" + title.replace(/"/g,"") + "\" \"" + body.replace(/"/g,"") + "\" 2>/dev/null"])
    }

    function settle() {
        if (Sfx.locked) { dev.primed = false; dev.pending = 4; return }
        if (dev.pending > 0) {
            dev.pending -= 1
            if (dev.pending === 0) dev.primed = true
        }
    }

    // ---- USB storage ----
    property string usbList: ""
    Process {
        id: usbProc
        command: ["sh","-c","lsblk -ndo NAME,TRAN 2>/dev/null | awk '$2==\"usb\"{print $1}' | sort | tr '\\n' ' '"]
        stdout: StdioCollector { onStreamFinished: {
            var v = text.trim()
            if (dev.primed && v !== dev.usbList) {
                var oldL = dev.usbList.split(" ").filter(function(x){return x !== ""})
                var newL = v.split(" ").filter(function(x){return x !== ""})
                var added = newL.filter(function(x){ return oldL.indexOf(x) < 0 })
                var gone  = oldL.filter(function(x){ return newL.indexOf(x) < 0 })
                if (added.length) { Sfx.play("connect");    dev.notify("USB CONNECTED", "/dev/" + added.join(", /dev/")) }
                if (gone.length)  { Sfx.play("disconnect"); dev.notify("USB REMOVED",   "/dev/" + gone.join(", /dev/")) }
            }
            dev.usbList = v
            dev.settle()
        } }
    }

    // ---- Bluetooth devices actually connected ----
    property string btList: ""
    property string btPending: ""
    property int    btStable: 0
    Process {
        id: btDevProc
        command: ["sh","-c","bluetoothctl devices Connected 2>/dev/null | sed -n 's/^Device \\(\\([0-9A-Fa-f][0-9A-Fa-f]:\\)\\{5\\}[0-9A-Fa-f][0-9A-Fa-f]\\) \\(.*\\)$/\\1=\\3/p' | sort | tr '\\n' ';'"]
        stdout: StdioCollector { onStreamFinished: {
            var v = text.trim()
            // debounce: a flapping device must report the same state twice
            if (v !== dev.btPending) { dev.btPending = v; dev.btStable = 0; dev.settle(); return }
            dev.btStable += 1
            if (dev.btStable < 2) { dev.settle(); return }
            if (dev.primed && v !== dev.btList) {
                var oldB = dev.btList.split(";").filter(function(x){return x !== ""})
                var newB = v.split(";").filter(function(x){return x !== ""})
                var addB = newB.filter(function(x){ return oldB.indexOf(x) < 0 })
                var remB = oldB.filter(function(x){ return newB.indexOf(x) < 0 })
                for (var i = 0; i < addB.length; i++) dev.btAnnounce(addB[i], true)
                for (var j = 0; j < remB.length; j++) dev.btAnnounce(remB[j], false)
            }
            dev.btList = v
            dev.settle()
        } }
    }

    // record is "MAC=Name" — no second lookup, nothing to mis-split
    function btAnnounce(record, connected) {
        var eq = record.indexOf("=")
        var name = eq > 0 ? record.substring(eq + 1) : record
        Sfx.muteNotify = true; unmute.restart()
        Sfx.play(connected ? "connect" : "disconnect")
        dev.notify(connected ? "BLUETOOTH CONNECTED" : "BLUETOOTH DISCONNECTED", name)
    }

    // ---- audio sinks (headphones plugged / unplugged) ----
    property string sinkList: ""
    property string sinkPending: ""
    property int    sinkStable: 0
    Process {
        id: sinkProc
        command: ["sh","-c","wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -oE '[0-9]+\\. .*' | sort | tr '\\n' '|'"]
        stdout: StdioCollector { onStreamFinished: {
            var v = text.trim()
            if (v !== dev.sinkPending) { dev.sinkPending = v; dev.sinkStable = 0; dev.settle(); return }
            dev.sinkStable += 1
            if (dev.sinkStable < 2) { dev.settle(); return }
            if (dev.primed && v !== dev.sinkList) {
                var was = dev.sinkList.split("|").filter(function(x){return x !== ""}).length
                var now = v.split("|").filter(function(x){return x !== ""}).length
                if (now !== was) {
                    Sfx.play(now > was ? "connect" : "disconnect")
                    dev.notify(now > was ? "AUDIO DEVICE CONNECTED" : "AUDIO DEVICE REMOVED",
                               now + " output" + (now === 1 ? "" : "s") + " available")
                }
            }
            dev.sinkList = v
            dev.settle()
        } }
    }

    // ---- charger ----
    property string acState: ""
    Process {
        id: acProc
        command: ["sh","-c","for p in /sys/class/power_supply/A*/online /sys/class/power_supply/AC*/online; do [ -f \"$p\" ] && cat \"$p\" && break; done"]
        stdout: StdioCollector { onStreamFinished: {
            var v = text.trim()
            if (dev.primed && v !== "" && v !== dev.acState) {
                Sfx.play(v === "1" ? "connect" : "disconnect")
                dev.notify(v === "1" ? "CHARGER CONNECTED" : "ON BATTERY",
                           v === "1" ? "power restored" : "running on battery")
            }
            if (v !== "") dev.acState = v
            dev.settle()
        } }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            usbProc.running = true
            btDevProc.running = true
            sinkProc.running = true
            acProc.running = true
        }
    }
}
