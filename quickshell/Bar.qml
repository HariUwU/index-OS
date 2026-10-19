// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  top bar (quickshell)
//  PanelWindow: emblem(start menu), workspaces, clock, tray, date.
//  + custom START MENU popup (apps + search + power).
//  NOTE: untested — Quickshell APIs (SystemTray.items, SystemClock,
//  DesktopEntries) match current docs but may need small tweaks.
//  Window list / desktops come from the KWin singleton (KWin.qml).
// ============================================================

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import "."

PanelWindow {
    screen: Screens.main
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: 32
    color: "transparent"
    WlrLayershell.namespace: "dock"

    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"
    readonly property color warn:  "#FF6B6B"
    readonly property string pixel: "Perfect DOS VGA 437 Universal"

    property bool menuOpen: false
    property bool taskMenuOpen: false
    property var  taskMenuWid: ""
    property bool taskMenuMin: false
    property real taskMenuX: 0
    // the context menu is shared: "task" = a window button, "pin" = a pinned icon
    property string taskMenuKind: "task"
    property string taskMenuApp: ""     // desktop-entry id ("" = unresolved)

    // ---- pinned apps: match KWin windows to desktop entries ----
    // KWin.windows is a ListModel; bump a counter so bindings re-scan it
    property int winRev: 0
    Connections {
        target: KWin.windows
        function onCountChanged() { bar.winRev++ }
        function onDataChanged() { bar.winRev++ }
        function onRowsMoved() { bar.winRev++ }
    }

    // desktop-entry id for a window's appId ("" if none)
    function entryIdFor(appId): string {
        var e = appId ? DesktopEntries.heuristicLookup(appId) : null
        return e && e.id ? String(e.id) : ""
    }

    // org.kde.dolphin <-> org.kde.dolphin / dolphin / heuristic hit
    function appMatches(appId, entryId): bool {
        var a = String(appId || "").toLowerCase()
        var e = String(entryId || "").toLowerCase()
        if (a === "" || e === "") return false
        if (a === e) return true
        if (a.split(".").pop() === e.split(".").pop()) return true
        return bar.entryIdFor(appId).toLowerCase() === e
    }

    // [{wid, desktop}] in model order (last = newest)
    function windowsFor(entryId): var {
        var out = []
        for (var i = 0; i < KWin.windows.count; i++) {
            var w = KWin.windows.get(i)
            if (bar.appMatches(w.appId, entryId)) out.push({ wid: w.wid, desktop: w.desktop })
        }
        return out
    }

    // Windows behavior: open -> toggle newest window, else launch
    function clickPinned(entryId): void {
        var ws = bar.windowsFor(entryId)
        if (ws.length === 0) { bar.launchPinned(entryId); return }
        var pick = null
        for (var i = 0; i < ws.length; i++)
            if (ws[i].wid === KWin.activeId) pick = ws[i]
        for (var j = ws.length - 1; !pick && j >= 0; j--)
            if (ws[j].desktop === 0 || ws[j].desktop === KWin.currentDesktop) pick = ws[j]
        if (!pick) pick = ws[ws.length - 1]
        KWin.toggle(pick.wid)
    }

    function launchPinned(entryId): void {
        var e = DesktopEntries.byId(entryId)
        if (e) e.execute()
    }

    Settings { id: settingsPanel }
    Calendar { id: calPopup }
    property bool wifiOpen: false
    property bool btOpen: false
    property bool notifOpen: false

    // lets a keybind toggle the start menu:  qs ipc call startmenu toggle
    IpcHandler {
        target: "startmenu"
        function toggle(): void { bar.menuOpen = !bar.menuOpen; Sfx.play("menu") }
        function open(): void   { bar.menuOpen = true }
        function close(): void  { bar.menuOpen = false }
    }
    IpcHandler {
        target: "settings"
        function open(): void { UiState.openSettings() }
        function intro(): void { UiState.openIntroSettings() }
        function close(): void { UiState.settingsOpen = false; UiState.introSettingsOpen = false }
    }

    // Meta key (via the KWin bridge) toggles the start menu
    Connections {
        target: KWin
        function onStartMenuRequested() { bar.menuOpen = !bar.menuOpen; Sfx.play("menu") }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: "#0a0e16"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: bar.cyan
        }

        // clock: sibling of the row so it centers on the BAR, not between items
        Text {
            id: barClock
            anchors.centerIn: parent
            z: 5
            text: Qt.formatDateTime(clock.date, "'_'hh:mm AP'._'")
            font.family: bar.pixel; font.pixelSize: 16
            color: bar.cyanB
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: calPopup.open = !calPopup.open
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 10

            // ---- emblem = START button ----
            Text {
                text: "// THE INDEX"
                font.family: bar.pixel; font.pixelSize: 15
                color: (startArea.containsMouse || bar.menuOpen) ? "#ffffff" : bar.cyanB
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: startArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { bar.menuOpen = !bar.menuOpen; Sfx.play("menu") }
                }
            }

            // ---- workspaces (KWin virtual desktops; wheel = switch) ----
            RowLayout {
                id: wsRow
                spacing: 5
                Repeater {
                    model: KWin.desktopCount
                    delegate: Rectangle {
                        required property int index
                        readonly property int ws: index + 1
                        readonly property bool active: KWin.currentDesktop === ws
                        implicitWidth: 22; implicitHeight: 20
                        color: active ? bar.cyan : "transparent"
                        Behavior on color { ColorAnimation { duration: 160 } }
                        scale: active ? 1.0 : 0.9
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        Text {
                            anchors.centerIn: parent
                            text: ws
                            font.family: bar.pixel; font.pixelSize: 15
                            color: active ? "#04141c" : bar.cyanD
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: KWin.goto(ws)
                        }
                    }
                }
                // a handler, not an Item, so the RowLayout doesn't place it
                WheelHandler {
                    onWheel: function(w) {
                        var n = KWin.currentDesktop + (w.angleDelta.y < 0 ? 1 : -1)
                        if (n >= 1 && n <= KWin.desktopCount) KWin.goto(n)
                    }
                }
            }

            // ---- TASKBAR: Windows-style task buttons (KWin bridge) ----
            RowLayout {
                id: taskRow
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.fillWidth: true
                // stop short of the centered clock
                Layout.maximumWidth: Math.max(0, barClock.x - taskRow.x - 14)
                spacing: 4

                // ---- PINNED APPS: icon squares (Pinned.qml) ----
                Repeater {
                    model: Pinned.ids
                    delegate: Rectangle {
                        id: pinBtn
                        required property var modelData
                        readonly property string entryId: modelData
                        readonly property var entry: DesktopEntries.byId(entryId)
                        readonly property var wins: { bar.winRev; return bar.windowsFor(entryId) }
                        readonly property bool running: wins.length > 0
                        readonly property bool hasActive: {
                            for (var i = 0; i < wins.length; i++)
                                if (wins[i].wid === KWin.activeId) return true
                            return false
                        }
                        Layout.preferredWidth: 24
                        Layout.minimumWidth: 24
                        Layout.maximumWidth: 24
                        implicitWidth: 24; implicitHeight: 22
                        color: pinMa.containsMouse ? "#143245" : "#0c1620"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        border.width: 1
                        border.color: hasActive ? bar.cyanB : bar.cyanD
                        Image {
                            id: pinIcon
                            anchors.centerIn: parent
                            width: 16; height: 16
                            sourceSize.width: 16; sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                            source: pinBtn.entry && pinBtn.entry.icon ? Quickshell.iconPath(pinBtn.entry.icon, true) : ""
                            visible: status === Image.Ready
                        }
                        // no icon -> first letter
                        Text {
                            anchors.centerIn: parent
                            visible: !pinIcon.visible
                            text: pinBtn.entry ? Glyph.clean(pinBtn.entry.name).charAt(0).toUpperCase() : "?"
                            font.family: bar.pixel; font.pixelSize: 13
                            color: bar.cyanB
                        }
                        // running = 2px underline, brighter when its window is active
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: pinBtn.hasActive ? parent.width - 4 : parent.width - 10
                            height: 2
                            visible: pinBtn.running
                            color: pinBtn.hasActive ? bar.cyanB : bar.cyan
                            opacity: pinBtn.hasActive ? 1 : 0.7
                            Behavior on width { NumberAnimation { duration: 140 } }
                        }
                        MouseArea {
                            id: pinMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.MiddleButton) { bar.launchPinned(pinBtn.entryId); return }
                                if (m.button === Qt.RightButton) {
                                    var p = pinBtn.mapToItem(null, 0, 0)
                                    bar.taskMenuX = p.x
                                    bar.taskMenuKind = "pin"
                                    bar.taskMenuApp = pinBtn.entryId
                                    bar.taskMenuWid = ""
                                    bar.taskMenuOpen = true
                                    return
                                }
                                bar.clickPinned(pinBtn.entryId)
                            }
                        }
                    }
                }
                // thin divider between pinned icons and task buttons
                Rectangle {
                    visible: Pinned.ids.length > 0
                    Layout.leftMargin: 2; Layout.rightMargin: 2
                    implicitWidth: 1; implicitHeight: 16
                    color: bar.cyanD
                    opacity: 0.8
                }

                Repeater {
                    model: KWin.windows
                    delegate: Rectangle {
                        id: task
                        required property var wid
                        required property string title
                        required property string appId
                        required property bool minimized
                        required property bool attention
                        required property int desktop
                        readonly property bool shown: desktop === 0 || desktop === KWin.currentDesktop
                        readonly property bool isActive: wid === KWin.activeId
                        readonly property string iconSrc: {
                            // the app's .desktop Icon= first (konsole -> utilities-terminal)
                            var e = DesktopEntries.heuristicLookup(appId)
                            var p = e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
                            if (p) return p
                            p = Quickshell.iconPath(appId, true)
                            if (p) return p
                            var last = String(appId).split(".").pop().toLowerCase()
                            return last ? Quickshell.iconPath(last, true) : ""
                        }
                        property real pulse: 0
                        visible: shown
                        Layout.preferredWidth: 200
                        Layout.maximumWidth: 200
                        Layout.minimumWidth: 40
                        Layout.fillWidth: true
                        implicitHeight: 22
                        color: isActive ? bar.cyan : (taskMa.containsMouse ? "#143245" : "#0c1620")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        border.width: (minimized && !isActive) ? 0 : 1
                        border.color: (attention && !isActive)
                            ? Qt.tint(bar.cyanD, Qt.rgba(1, 0.42, 0.42, pulse))
                            : (isActive ? bar.cyanB : bar.cyanD)
                        SequentialAnimation on pulse {
                            running: task.attention && !task.isActive && task.shown
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: 500 }
                            NumberAnimation { to: 0; duration: 500 }
                        }
                        Image {
                            id: taskIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 4
                            width: 14; height: 14
                            sourceSize.width: 14; sourceSize.height: 14
                            fillMode: Image.PreserveAspectFit
                            source: task.iconSrc
                            visible: status === Image.Ready
                            opacity: task.minimized ? 0.55 : 1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: taskIcon.visible ? 22 : 6
                            anchors.right: parent.right; anchors.rightMargin: 6
                            text: Glyph.clean(task.title) || task.appId || "window"
                            font.family: bar.pixel; font.pixelSize: 12
                            color: task.isActive ? "#04141c" : bar.cyanB
                            opacity: task.minimized ? 0.55 : 1
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: taskMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.MiddleButton) { KWin.close(task.wid); return }
                                if (m.button === Qt.RightButton) {
                                    var p = task.mapToItem(null, 0, 0)
                                    bar.taskMenuX = p.x
                                    bar.taskMenuWid = task.wid
                                    bar.taskMenuMin = task.minimized
                                    bar.taskMenuKind = "task"
                                    bar.taskMenuApp = bar.entryIdFor(task.appId)
                                    bar.taskMenuOpen = true
                                    return
                                }
                                KWin.toggle(task.wid)
                            }
                        }
                    }
                }
                // soaks up spare width so pinned icons + tasks stay packed to the left
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
            }

            // single spacer: everything after this sits on the right
            Item { Layout.fillWidth: true }


            RowLayout {
                spacing: 10
                // ---- keyboard layout (click = switch) ----
                Text {
                    id: kbText
                    property string layout: "EN"
                    text: "[" + layout + "]"
                    font.family: bar.pixel; font.pixelSize: 13
                    color: layout === "TH" ? bar.cyanB : bar.cyanD
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["sh","-c","fcitx5-remote -t"])
                            kbPoll.restart()
                        }
                    }
                }

                // ---- notification history ----
                Text {
                    text: "[!]"
                    font.family: bar.pixel; font.pixelSize: 13
                    color: bar.notifOpen ? bar.cyanB : bar.cyanD
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { bar.notifOpen = !bar.notifOpen; Sfx.play("menu") } }
                }

                // ---- media (playerctl): title + play/pause, click to toggle ----
                RowLayout {
                    spacing: 5
                    visible: mediaText.status !== ""
                    Text {
                        text: mediaText.status === "Playing" ? "[>]" : "[||]"
                        font.family: bar.pixel; font.pixelSize: 13
                        color: mediaText.status === "Playing" ? bar.cyanB : bar.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { Quickshell.execDetached(["playerctl","play-pause"]); mediaPoll.restart() } }
                    }
                    Text {
                        id: mediaText
                        property string status: ""
                        property string title: ""
                        text: title
                        font.family: bar.pixel; font.pixelSize: 13; color: bar.cyanD
                        elide: Text.ElideRight
                        Layout.maximumWidth: 170
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.RightButton) Quickshell.execDetached(["playerctl","next"])
                                else Quickshell.execDetached(["playerctl","previous"])
                                mediaPoll.restart()
                            }
                        }
                    }
                }
                Process {
                    id: kbGet
                    command: ["sh","-c","fcitx5-remote -n 2>/dev/null || echo keyboard-us"]
                    stdout: StdioCollector { onStreamFinished: {
                        var t = text.trim().toLowerCase()
                        if (t.indexOf("th") >= 0) kbText.layout = "TH"
                        else if (t.length > 0)    kbText.layout = "EN"
                    } }
                }
                Timer { id: kbPoll; interval: 80; repeat: false; onTriggered: kbGet.running = true }
                Timer { interval: 1000; running: true; repeat: true; onTriggered: kbGet.running = true }

                Process {
                    id: mediaGet
                    command: ["sh","-c","s=$(playerctl status 2>/dev/null); [ -z \"$s\" ] && exit 0; t=$(playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | cut -c1-40); printf '%s|%s' \"$s\" \"$t\""]
                    stdout: StdioCollector { onStreamFinished: {
                        var t = text.trim()
                        if (t === "") { mediaText.status = ""; mediaText.title = ""; return }
                        var f = t.split("|")
                        mediaText.status = f[0] || ""
                        mediaText.title  = Glyph.clean((f[1] || "").replace(/^ - /, ""))
                    } }
                }
                Timer { id: mediaPoll; interval: 600; repeat: false; onTriggered: mediaGet.running = true }

                // ---- network (click = open editor) ----
                Text {
                    id: netText
                    property string ssid: ""
                    property bool primed: false
                    text: ssid === "" ? "NET --" : "NET " + ssid
                    font.family: bar.pixel; font.pixelSize: 13
                    color: ssid === "" ? bar.warn : bar.cyanD
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { bar.wifiOpen = !bar.wifiOpen; Sfx.play("menu"); if (bar.wifiOpen) scanProc.running = true }
                    }
                }
                Process {
                    id: netProc
                    command: ["sh","-c","nmcli -t -f NAME connection show --active 2>/dev/null | head -1"]
                    stdout: StdioCollector { onStreamFinished: {
                        var v = text.trim()
                        if (netText.primed && v !== netText.ssid)
                            Sfx.play(v === "" ? "disconnect" : "connect")
                        netText.primed = true
                        netText.ssid = v
                    } }
                }

                // ---- bluetooth (click = manager) ----
                Text {
                    id: btText
                    property bool on: false
                    property bool primed: false
                    text: on ? "BT ON" : "BT --"
                    font.family: bar.pixel; font.pixelSize: 13
                    color: on ? bar.cyan : bar.cyanD
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { bar.btOpen = !bar.btOpen; Sfx.play("menu") }
                    }
                }
                Process {
                    id: btProc
                    command: ["sh","-c","[ -d /sys/class/bluetooth ] || exit 0; timeout -k 1 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
                    stdout: StdioCollector { onStreamFinished: {
                        btText.on = (text.trim() === "1")
                    } }
                }

                // ---- battery (hidden on desktops) ----
                Text {
                    id: batText
                    property int pct: -1
                    property bool charging: false
                    visible: pct >= 0
                    text: (charging ? "BAT+ " : "BAT ") + pct + "%"
                    font.family: bar.pixel; font.pixelSize: 13
                    color: pct <= 15 && !charging ? bar.warn : bar.cyanD
                }
                Process {
                    id: batProc
                    command: ["sh","-c","c=/sys/class/power_supply/BAT0; [ -d $c ] || c=/sys/class/power_supply/BAT1; if [ -d $c ]; then printf '%s %s' \"$(cat $c/capacity)\" \"$(cat $c/status)\"; else echo '-1 none'; fi"]
                    stdout: StdioCollector { onStreamFinished: {
                        var p = text.trim().split(" ")
                        batText.pct = parseInt(p[0])
                        batText.charging = (p[1] === "Charging" || p[1] === "Full")
                    } }
                }

                // poll them
                Timer {
                    interval: 10000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: { netProc.running = true; btProc.running = true; batProc.running = true; mediaGet.running = true; kbGet.running = true }
                }

                // volume control — scroll to change, click to mute (live from PipeWire)
                PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
                Text {
                    id: volText
                    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                    readonly property int vol: audio ? Math.round(audio.volume * 100) : 0
                    readonly property bool muted: audio ? audio.muted : false
                    text: !audio ? "VOL --" : muted ? "VOL MUTE" : "VOL " + vol
                    font.family: bar.pixel; font.pixelSize: 13
                    color: muted ? bar.warn : bar.cyanD
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(m) {
                            if (m.button === Qt.RightButton) { UiState.settingsOpen = !UiState.settingsOpen; Sfx.play("menu"); return }
                            if (volText.audio) volText.audio.muted = !volText.audio.muted
                        }
                        onWheel: function(w) {
                            if (!volText.audio) return
                            var d = w.angleDelta.y > 0 ? 0.05 : -0.05
                            volText.audio.muted = false
                            volText.audio.volume = Math.max(0, Math.min(1, volText.audio.volume + d))
                        }
                    }
                }
                Repeater {
                    model: SystemTray.items
                    delegate: Image {
                        id: trayIcon
                        required property var modelData
                        source: modelData.icon
                        width: 16; height: 16
                        sourceSize.width: 16; sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(m) {
                                if (m.button === Qt.LeftButton) { modelData.activate(); return }
                                if (!modelData.hasMenu) return
                                // anchor the menu under THIS icon, in bar coordinates
                                var p = trayIcon.mapToItem(null, trayIcon.width / 2, trayIcon.height)
                                modelData.display(bar, p.x, bar.implicitHeight)
                            }
                        }
                    }
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                    font.family: bar.pixel; font.pixelSize: 13
                    color: bar.cyanD
                }
                // ---- QUICK SETTINGS (Win+A) — Windows 11's corner button ----
                Rectangle {
                    visible: Features.enabled("quicksettings")
                    implicitWidth: qsLabel.implicitWidth + 12; implicitHeight: 20
                    color: UiState.quickSettingsOpen ? bar.cyan : (qsArea.containsMouse ? "#143245" : "transparent")
                    border.color: UiState.quickSettingsOpen ? bar.cyanB : bar.cyanD; border.width: 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text {
                        id: qsLabel
                        anchors.centerIn: parent
                        text: UiState.doNotDisturb ? "[≡ z]" : "[≡]"
                        font.family: bar.pixel; font.pixelSize: 13
                        color: UiState.quickSettingsOpen ? "#04141c" : bar.cyanB
                    }
                    MouseArea {
                        id: qsArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { UiState.toggleQuickSettings(); Sfx.play("menu") }
                    }
                }
            }
        }
    }

    // ===================== WIFI MENU =====================
    PanelWindow {
        screen: Screens.main
        id: wifiMenu
        visible: bar.wifiOpen
        anchors { top: true; right: true }
        margins { top: bar.implicitHeight; right: 8 }
        implicitWidth: 320
        implicitHeight: 380
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "index-wifi"

        property var nets: []
        property string pending: ""
        property bool scanned: false

        Process {
            id: scanProc
            command: ["sh","-c","nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes 2>/dev/null | head -20"]
            onRunningChanged: if (running) wifiMenu.scanned = false
            stdout: StdioCollector { onStreamFinished: {
                wifiMenu.scanned = true
                var out = []
                var lines = text.trim().split("\n")
                for (var i=0;i<lines.length;i++) {
                    if (!lines[i]) continue
                    var f = lines[i].split(":")
                    if (f.length < 4 || !f[3]) continue
                    out.push({ active: f[0]==="*", signal: parseInt(f[1])||0,
                               secure: (f[2]||"").trim()!=="", ssid: f.slice(3).join(":") })
                }
                wifiMenu.nets = out
            } }
        }
        Process { id: connProc; command: ["true"] }

        Rectangle {
            anchors.fill: parent
            color: "#0a0e16"
            border.color: bar.cyan; border.width: 2
            opacity: bar.wifiOpen ? 1 : 0
            transform: Translate { y: bar.wifiOpen ? 0 : -18
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: ">_ NETWORKS_"; font.family: bar.pixel; font.pixelSize: 16; color: bar.cyanB }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "[SCAN]"; font.family: bar.pixel; font.pixelSize: 12; color: bar.cyan
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: scanProc.running = true }
                    }
                    Text {
                        text: "[X]"; font.family: bar.pixel; font.pixelSize: 12; color: bar.warn
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: bar.wifiOpen = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: bar.cyanD; opacity: 0.6 }

                // password prompt
                Rectangle {
                    Layout.fillWidth: true; height: 34
                    visible: wifiMenu.pending !== ""
                    color: "#0c1620"; border.color: bar.cyan; border.width: 1
                    TextInput {
                        id: wifiPass
                        anchors.fill: parent; anchors.margins: 7
                        font.family: bar.pixel; font.pixelSize: 13
                        color: bar.cyanB; echoMode: TextInput.Password
                        onAccepted: {
                            connProc.command = ["sh","-c","nmcli device wifi connect '" + wifiMenu.pending.replace(/'/g,"") + "' password '" + text.replace(/'/g,"") + "'"]
                            connProc.running = true
                            wifiMenu.pending = ""; text = ""
                            reScan.start()
                        }
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        visible: wifiPass.text === ""
                        text: "password for " + wifiMenu.pending
                        font.family: bar.pixel; font.pixelSize: 12; color: bar.cyanD
                    }
                }

                Text {
                    visible: wifiMenu.nets.length === 0
                    text: wifiMenu.scanned ? "  no wi-fi networks found." : "  scanning..."
                    font.family: bar.pixel; font.pixelSize: 12; color: bar.cyanD
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 3
                    model: wifiMenu.nets
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 30
                        color: netMa.containsMouse ? "#143245" : (modelData.active ? "#0c2634" : "transparent")
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (modelData.active ? "* " : "  ") + modelData.ssid
                            font.family: bar.pixel; font.pixelSize: 13
                            color: modelData.active ? bar.cyanB : bar.cyan
                            elide: Text.ElideRight
                            width: parent.width - 80
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (modelData.secure ? "[#] " : "") + modelData.signal
                            font.family: bar.pixel; font.pixelSize: 11; color: bar.cyanD
                        }
                        MouseArea {
                            id: netMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.active) return
                                if (modelData.secure) { wifiMenu.pending = modelData.ssid; wifiPass.forceActiveFocus() }
                                else {
                                    connProc.command = ["sh","-c","nmcli device wifi connect '" + modelData.ssid.replace(/'/g,"") + "'"]
                                    connProc.running = true; reScan.start()
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: ">_ advanced settings _<"
                    font.family: bar.pixel; font.pixelSize: 11; color: bar.cyanD
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"]); bar.wifiOpen = false } }
                }
            }
        }
        Timer { id: reScan; interval: 2500; repeat: false; onTriggered: { scanProc.running = true; netProc.running = true } }
        Keys.onEscapePressed: bar.wifiOpen = false
    }

    // click anywhere outside the start menu to close it
    PanelWindow {
        screen: Screens.main
        id: menuDismiss
        visible: bar.menuOpen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "index-menu-dismiss"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: bar.menuOpen = false
        }
    }

    // ================= TASK CONTEXT MENU =================
    // click anywhere outside to close
    PanelWindow {
        screen: Screens.main
        id: taskMenuDismiss
        visible: bar.taskMenuOpen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "index-menu-dismiss"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: bar.taskMenuOpen = false
        }
    }

    PanelWindow {
        screen: Screens.main
        id: taskMenu
        visible: bar.taskMenuOpen
        anchors { top: true; left: true }
        margins { top: bar.implicitHeight; left: Math.max(0, bar.taskMenuX) }
        implicitWidth: 190
        implicitHeight: taskCol.implicitHeight + 4
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "index-task-menu"

        property var entries: {
            var app = bar.taskMenuApp
            var pinned = Pinned.isPinned(app)
            // pinned icon: launch / unpin only
            if (bar.taskMenuKind === "pin")
                return [
                    { label: "NEW WINDOW", act: "launch" },
                    { label: "UNPIN FROM TASKBAR", act: "unpin" }
                ]
            var out = [
                { label: bar.taskMenuMin ? "RESTORE" : "MINIMIZE", act: "toggle" },
                { label: "MAXIMIZE", act: "maximize" }
            ]
            // hidden when the window's app has no desktop entry
            if (app !== "")
                out.push(pinned ? { label: "UNPIN FROM TASKBAR", act: "unpin" }
                                : { label: "PIN TO TASKBAR", act: "pin" })
            for (var i = 1; i <= KWin.desktopCount; i++)
                out.push({ label: "MOVE TO DESKTOP " + i, act: "send", n: i })
            out.push({ label: "CLOSE", act: "close", danger: true })
            return out
        }

        function run(e): void {
            var w = bar.taskMenuWid
            if (e.act === "toggle")        KWin.toggle(w)
            else if (e.act === "maximize") KWin.maximize(w)
            else if (e.act === "send")     KWin.sendTo(w, e.n)
            else if (e.act === "close")    KWin.close(w)
            else if (e.act === "pin")      Pinned.pin(bar.taskMenuApp)
            else if (e.act === "unpin")    Pinned.unpin(bar.taskMenuApp)
            else if (e.act === "launch")   bar.launchPinned(bar.taskMenuApp)
            bar.taskMenuOpen = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#0a0e16"
            border.color: bar.cyan; border.width: 1
            opacity: bar.taskMenuOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Column {
                id: taskCol
                anchors.fill: parent; anchors.margins: 2
                Repeater {
                    model: taskMenu.entries
                    delegate: Rectangle {
                        required property var modelData
                        width: taskCol.width; height: 24
                        color: tmArea.containsMouse ? (modelData.danger ? bar.warn : bar.cyanD) : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8
                            text: modelData.label
                            font.family: bar.pixel; font.pixelSize: 12
                            color: tmArea.containsMouse ? "#04141c" : (modelData.danger ? bar.warn : bar.cyanB)
                        }
                        MouseArea {
                            id: tmArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: taskMenu.run(modelData)
                        }
                    }
                }
            }
        }
        Keys.onEscapePressed: bar.taskMenuOpen = false
    }

    // ================= NOTIFICATION HISTORY ==============
    PanelWindow {
        screen: Screens.main
        id: notifPanel
        visible: bar.notifOpen
        anchors { top: true; right: true }
        margins { top: bar.implicitHeight; right: 8 }
        implicitWidth: 360
        implicitHeight: 440
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "index-notif-history"

        Rectangle {
            anchors.fill: parent
            color: "#0a0e16"; border.color: bar.cyan; border.width: 2
            opacity: bar.notifOpen ? 1 : 0
            transform: Translate { y: bar.notifOpen ? 0 : -14
                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: ">_ NOTIFICATIONS_"; font.family: bar.pixel; font.pixelSize: 16; color: bar.cyanB }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "[CLEAR]"; font.family: bar.pixel; font.pixelSize: 11; color: bar.cyanD
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: NotifHistory.clear() }
                    }
                    Text {
                        text: "[X]"; font.family: bar.pixel; font.pixelSize: 12; color: bar.warn
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: bar.notifOpen = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: bar.cyanD; opacity: 0.6 }

                Text {
                    visible: NotifHistory.items.length === 0
                    Layout.fillWidth: true
                    text: "  nothing yet."
                    font.family: bar.pixel; font.pixelSize: 12; color: bar.cyanD
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: NotifHistory.items
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: nCol.implicitHeight + 12
                        color: "#0c1620"
                        border.color: modelData.critical ? bar.warn : bar.cyanD
                        border.width: 1
                        Column {
                            id: nCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.margins: 7
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: modelData.time + "  " + modelData.app
                                font.family: bar.pixel; font.pixelSize: 9; color: bar.cyanD
                            }
                            Text {
                                width: parent.width
                                text: modelData.summary
                                font.family: bar.pixel; font.pixelSize: 13
                                color: modelData.critical ? bar.warn : bar.cyanB
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                width: parent.width
                                visible: (modelData.body || "") !== ""
                                text: modelData.body
                                font.family: bar.pixel; font.pixelSize: 11; color: bar.cyan
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================== BLUETOOTH =====================
    PanelWindow {
        screen: Screens.main
        id: btMenu
        visible: bar.btOpen
        anchors { top: true; right: true }
        margins { top: bar.implicitHeight; right: 8 }
        implicitWidth: 340
        implicitHeight: 420
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "index-bluetooth"

        BluetoothMenu {
            anchors.fill: parent
            onRequestClose: bar.btOpen = false
        }
    }

    // ===================== START MENU =====================
    PanelWindow {
        screen: Screens.main
        id: startMenu
        visible: bar.menuOpen
        anchors { top: true; left: true }
        margins { top: bar.implicitHeight; left: 8 }
        implicitWidth: 340
        implicitHeight: 480
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "index-startmenu"
        onVisibleChanged: {
            if (visible) {
                // always start fresh: clear the query and jump to the first result
                search.text = ""
                startMenu.query = ""
                appList.currentIndex = 0
                appList.positionViewAtBeginning()
                search.forceActiveFocus()
            }
        }

        property string query: ""
        function launchCurrent(): void {
            var apps = startMenu.shownApps
            if (!apps || apps.length === 0) return
            var i = appList.currentIndex
            if (i < 0 || i >= apps.length) i = 0
            apps[i].execute()
            bar.menuOpen = false
        }
        property var shownApps: {
            var all = DesktopEntries.applications.values
            if (!all) return []
            function key(a) { return Glyph.clean(a.name).toLowerCase() }
            // A-Z like the Windows start menu; hidden entries stay hidden
            all = all.filter(function(a) { return !a.noDisplay })
                     .sort(function(a, b) { return key(a).localeCompare(key(b)) })
            if (startMenu.query.length === 0) return all
            var q = startMenu.query.toLowerCase()
            // names that START with the search come first, then the rest that contain it
            var starts = [], contains = []
            for (var i = 0; i < all.length; i++) {
                var k = key(all[i])
                if (k.indexOf(q) === 0) starts.push(all[i])
                else if (k.indexOf(q) > 0) contains.push(all[i])
            }
            return starts.concat(contains)
        }

        Rectangle {
            anchors.fill: parent
            color: "#05080d"
            border.color: bar.cyan
            border.width: 2
            opacity: bar.menuOpen ? 1 : 0
            transform: Translate { y: bar.menuOpen ? 0 : -18
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: ">_ THE INDEX // START_"
                    font.family: bar.pixel; font.pixelSize: 16; color: bar.cyanB
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: bar.cyanD; opacity: 0.6 }

                // search
                Rectangle {
                    Layout.fillWidth: true; height: 32
                    color: "#0a0e16"; border.color: bar.cyanD; border.width: 1
                    TextInput {
                        id: search
                        anchors.fill: parent; anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: bar.pixel; font.pixelSize: 15; color: bar.cyanB
                        focus: bar.menuOpen
                        onTextChanged: { startMenu.query = text; appList.currentIndex = 0 }
                        Keys.onEscapePressed: bar.menuOpen = false
                        // arrows / Tab move the selection, Enter launches
                        Keys.onDownPressed:  appList.incrementCurrentIndex()
                        Keys.onUpPressed:    appList.decrementCurrentIndex()
                        Keys.onTabPressed:   appList.incrementCurrentIndex()
                        Keys.onBacktabPressed: appList.decrementCurrentIndex()
                        Keys.onReturnPressed: startMenu.launchCurrent()
                        Keys.onEnterPressed:  startMenu.launchCurrent()
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: search.text.length === 0
                            text: "search._"; color: bar.cyanD
                            font.family: bar.pixel; font.pixelSize: 15
                        }
                    }
                }

                // app list
                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    model: startMenu.shownApps
                    currentIndex: 0
                    highlightMoveDuration: 90
                    keyNavigationWraps: true
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool selected: appList.currentIndex === index
                        readonly property bool pinned: Pinned.isPinned(modelData.id)
                        width: appList.width; height: 30
                        color: (appArea.containsMouse || selected) ? bar.cyanD : "transparent"
                        Image {
                            id: appIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 8
                            width: 18; height: 18
                            sourceSize.width: 18; sourceSize.height: 18
                            fillMode: Image.PreserveAspectFit
                            source: Quickshell.iconPath(modelData.icon, true)
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: appIcon.visible ? 32 : 8
                            text: Glyph.clean(modelData.name)
                            font.family: bar.pixel; font.pixelSize: 15
                            color: (appArea.containsMouse || parent.selected) ? "#04141c" : bar.cyanB
                            elide: Text.ElideRight
                            width: parent.width - (appIcon.visible ? 40 : 16) - (parent.pinned ? 32 : 0)
                        }
                        // pinned-to-taskbar marker
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 8
                            visible: parent.pinned
                            text: "[P]"
                            font.family: bar.pixel; font.pixelSize: 11
                            color: (appArea.containsMouse || parent.selected) ? "#04141c" : bar.cyanD
                        }
                        MouseArea {
                            id: appArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: appList.currentIndex = index
                            onClicked: function(m) {
                                // right-click = pin / unpin, menu stays open
                                if (m.button === Qt.RightButton) { Pinned.toggle(modelData.id); return }
                                modelData.execute(); bar.menuOpen = false
                            }
                        }
                    }
                }

                // power row
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [
                            { label: "LOCK",   cmd: ["qdbus6", "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"] },
                            { label: "LOGOUT", cmd: ["qdbus6","org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logout"] },
                            { label: "SLEEP",  cmd: ["systemctl", "suspend"], battery: true },
                            { label: "REBOOT", cmd: ["qdbus6","org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logoutAndReboot"] },
                            { label: "POWER OFF", cmd: ["qdbus6","org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logoutAndShutdown"] }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            // entries marked battery:true only show on laptops
                            visible: !modelData.battery || batText.pct >= 0
                            Layout.fillWidth: true; height: 30
                            color: powArea.containsMouse ? bar.warn : "transparent"
                            border.color: bar.warn; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: bar.pixel; font.pixelSize: 12
                                color: powArea.containsMouse ? "#04141c" : bar.warn
                            }
                            MouseArea {
                                id: powArea
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Quickshell.execDetached(modelData.cmd); bar.menuOpen = false }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================== SETTINGS PANEL =====================
    PanelWindow {
        screen: Screens.main
        id: settingsWin
        visible: UiState.settingsOpen
        anchors { top: true; right: true }
        margins { top: bar.implicitHeight; right: 8 }
        implicitWidth: 340
        implicitHeight: Math.min(920, Screens.main.height - bar.implicitHeight - 12)
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "index-settings"

        Flickable {
            anchors.fill: parent; clip: true
            contentHeight: settingsContent.implicitHeight
            contentWidth: width
            SettingsPanel {
                id: settingsContent
                width: parent.width; implicitHeight: 980; height: implicitHeight
                onRequestClose: UiState.settingsOpen = false
                onRequestIntroSettings: UiState.openIntroSettings()
            }
        }
    }
}
