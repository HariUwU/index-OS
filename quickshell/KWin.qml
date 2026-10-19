pragma Singleton
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  KWin window state for QML
//  Stand-in for ToplevelManager (KWin has no wlr-foreign-toplevel).
//  Runs ~/.local/share/index/bridge/index-kwin-bridge and keeps
//  `windows` (ListModel, stable order) in sync with KWin.
//
//  windows rows:  wid, title, appId, minimized, attention, desktop
//                 (desktop 0 = on all desktops)
//  functions:     toggle(wid) activate(wid) minimize(wid) close(wid)
//                 maximize(wid) sendTo(wid, n) goto(n)
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string activeId: ""
    property int currentDesktop: 1
    property var desktopNames: ["1"]
    property var obscuredOutputs: []
    property bool showingDesktop: false
    readonly property int desktopCount: desktopNames.length
    readonly property bool ready: proc.running && seen
    property bool seen: false

    readonly property ListModel windows: ListModel {}

    // Meta key (kwinrc ModifierOnlyShortcuts -> bridge ToggleStartMenu)
    signal startMenuRequested()
    // a Windows-style shortcut registered in kwin-bridge.js was pressed
    // (name: "files", "clipboard", "quicksettings", "screenshot", "taskmgr", "settings")
    signal shortcut(string name)

    function toggle(wid)      { send("toggle " + wid) }
    function activate(wid)    { send("activate " + wid) }
    function minimize(wid)    { send("minimize " + wid) }
    function close(wid)       { send("close " + wid) }
    function maximize(wid)    { send("maximize " + wid) }
    function sendTo(wid, n)   { send("send " + wid + " " + n) }
    function goto(n)          { currentDesktop = n; send("desktop " + n) }

    function send(line) {
        if (proc.running) proc.write(line + "\n")
    }

    // update the model in place so delegates (and their animations) survive
    function apply(json) {
        let s
        try { s = JSON.parse(json) } catch (e) { return }
        if (s.event === "startmenu") { startMenuRequested(); return }
        if (s.event === "shortcut") { shortcut(s.name); return }
        if (s.event === "showdesktop") { showingDesktop = s.showing; return }
        seen = true
        activeId = s.active
        currentDesktop = s.current
        desktopNames = s.names
        obscuredOutputs = s.obscuredOutputs || []

        const want = {}
        for (const w of s.windows) want[w.id] = w
        for (let i = windows.count - 1; i >= 0; i--)
            if (!(windows.get(i).wid in want)) windows.remove(i)

        for (let i = 0; i < s.windows.length; i++) {
            const w = s.windows[i]
            const row = { wid: w.id, title: w.title, appId: w.appId,
                          minimized: w.minimized, attention: w.attention, desktop: w.desktop }
            if (i < windows.count && windows.get(i).wid === w.id) {
                windows.set(i, row)
                continue
            }
            let at = -1
            for (let j = i + 1; j < windows.count; j++)
                if (windows.get(j).wid === w.id) { at = j; break }
            if (at >= 0) { windows.move(at, i, 1); windows.set(i, row) }
            else windows.insert(i, row)
        }
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/share/index/bridge/index-kwin-bridge"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.apply(data) }
        stderr: SplitParser { onRead: data => console.warn("kwin-bridge:", data) }
        onExited: { root.seen = false; restart.start() }
    }

    // KWin restarts (or a crash) shouldn't leave the taskbar empty for good
    Timer { id: restart; interval: 2000; onTriggered: proc.running = true }
}
