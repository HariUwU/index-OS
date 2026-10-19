// Intro preferences use the same validated helper as source setup.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Dialogs as Dialogs
import QtCore
import QtMultimedia
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: window
    title: "INDEX — Intro Video"
    visible: UiState.introSettingsOpen
    screen: Screens.main
    implicitWidth: 580
    implicitHeight: Math.min(630, Screens.main.height - 80)
    minimumSize: Qt.size(450, 450)
    color: "#0a0e16"
    onClosed: UiState.introSettingsOpen = false
    onVisibleChanged: {
        if (visible) refresh()
        else { player.stop(); fileDialog.close() }
    }

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan: "#5DADE2"
    readonly property color bright: "#85C5E8"
    readonly property color dim: "#3A7CA5"
    readonly property color warning: "#FF6B6B"
    readonly property string helper: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/index/tools/index-intro.py"
    property string scope: "user"
    property var saved: ({})
    property bool loaded: false
    property string selectedPath: ""
    property url selectedUrl: ""
    property string message: ""
    property bool failed: false
    property string errorOutput: ""
    readonly property var current: saved[scope] || ({enabled: false, custom: false, installed: false})
    readonly property bool busy: applyProcess.running || statusProcess.running

    function refresh() {
        if (!statusProcess.running) statusProcess.running = true
    }
    function chooseScope(value) {
        if (busy || scope === value) return
        player.stop(); scope = value; selectedPath = ""; selectedUrl = ""; message = ""
    }
    function apply(action) {
        if (busy || !loaded || !current.installed) return
        player.stop(); failed = false; message = "Applying changes…"; errorOutput = ""
        applyProcess.command = ["python3", helper, "--gui", "--scope", scope].concat(action)
        applyProcess.running = true
    }

    Process {
        id: statusProcess
        command: ["python3", window.helper, "--gui", "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text)
                    if (!value.user || !value.login) throw new Error("Missing screen settings")
                    window.saved = value; window.loaded = true
                } catch (e) {
                    window.loaded = false; window.failed = true
                    window.message = "Could not load intro settings. Reinstall the INDEX desktop and try again."
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                window.loaded = false; window.failed = true
                window.message = "Could not load intro settings. Reinstall the INDEX desktop and try again."
            }
        }
    }
    Process {
        id: applyProcess
        stderr: StdioCollector { onStreamFinished: window.errorOutput = text.trim() }
        onExited: (code, status) => {
            window.failed = code !== 0
            if (code === 0) {
                window.message = "Saved. " + (window.scope === "user" ? "Your next lock screen will use these settings." : "Login playback follows the frequency selected below.")
                window.selectedPath = ""; window.selectedUrl = ""
            } else {
                const lines = window.errorOutput.split("\n")
                window.message = lines[lines.length - 1] || "Changes could not be applied. Please try again."
                window.message = window.message.replace(/^.*error: /, "")
            }
            window.refresh()
        }
    }
    Dialogs.FileDialog {
        id: fileDialog
        title: "Choose an intro video"
        fileMode: Dialogs.FileDialog.OpenFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
        nameFilters: ["Videos (*.mp4 *.webm *.mkv *.mov *.m4v *.avi)", "All files (*)"]
        onAccepted: {
            const url = selectedFile.toString()
            if (!url.startsWith("file:///")) {
                window.failed = true; window.message = "Choose a video stored on this computer."
                return
            }
            window.selectedUrl = selectedFile
            window.selectedPath = decodeURIComponent(url.slice(7))
            window.failed = false; window.message = "Video selected. Preview it, then choose Use Video to save."
        }
    }
    MediaPlayer {
        id: player
        source: window.selectedUrl
        videoOutput: video
        audioOutput: AudioOutput { volume: 0.4 }
        onErrorOccurred: {
            window.failed = true
            window.message = "This video could not be previewed. Choose another video."
        }
    }

    component IndexButton: Controls.Button {
        id: button
        implicitHeight: 34
        implicitWidth: contentItem.implicitWidth + 22
        font.family: window.pixel
        font.pixelSize: 13
        opacity: enabled ? 1 : 0.4
        contentItem: Text {
            text: button.text; font: button.font; color: window.bright
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: button.down || button.hovered ? "#143245" : "#0c1620"
            border.color: button.activeFocus ? window.bright : window.dim
        }
    }

    Rectangle {
        anchors.fill: parent; border.color: window.cyan; color: "transparent"
        Controls.ScrollView {
            id: introScroll
            anchors.fill: parent; anchors.margins: 18
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: introScroll.availableWidth; spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: ">_ INTRO VIDEO_"; font.family: window.pixel; font.pixelSize: 20; color: window.bright }
                    IndexButton { text: "CLOSE"; onClicked: UiState.introSettingsOpen = false }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Choose the video that plays before your password."
                    font.family: window.pixel; font.pixelSize: 14; color: window.dim
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    IndexButton {
                        Layout.fillWidth: true; text: "LOCK SCREEN"; enabled: !window.busy
                        highlighted: window.scope === "user"
                        background: Rectangle { color: window.scope === "user" ? "#143245" : "#0c1620"; border.color: window.scope === "user" ? window.bright : window.dim }
                        onClicked: window.chooseScope("user")
                    }
                    IndexButton {
                        Layout.fillWidth: true; text: "LOGIN SCREEN"; enabled: !window.busy
                        background: Rectangle { color: window.scope === "login" ? "#143245" : "#0c1620"; border.color: window.scope === "login" ? window.bright : window.dim }
                        onClicked: window.chooseScope("login")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: !window.loaded ? "Loading…" : !window.current.installed ? "Screen is not installed" : !window.current.available ? "No video supplied — choose your own" : window.current.custom ? "Current: custom video" : "Current: your assets/intro.mp4"
                        font.family: window.pixel; font.pixelSize: 14; color: window.bright
                    }
                    IndexButton {
                        text: window.current.enabled && window.current.available ? "INTRO: ON" : "INTRO: OFF"
                        enabled: !window.busy && window.loaded && window.current.installed && window.current.available
                        onClicked: window.apply([window.current.enabled ? "--disable" : "--enable"])
                    }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: window.scope === "login" ? "Login-screen changes ask for your Linux password." : "Press Win+L after saving to try your lock-screen intro."
                    font.family: window.pixel; font.pixelSize: 12; color: window.dim
                }
                RowLayout {
                    visible: window.scope === "login"
                    Layout.fillWidth: true; spacing: 8
                    IndexButton {
                        Layout.fillWidth: true; text: "ONCE PER BOOT"
                        enabled: !window.busy && window.loaded && window.current.installed
                        background: Rectangle { color: window.current.frequency !== "always" ? "#143245" : "#0c1620"; border.color: window.current.frequency !== "always" ? window.bright : window.dim }
                        onClicked: window.apply(["--frequency", "boot"])
                    }
                    IndexButton {
                        Layout.fillWidth: true; text: "EVERY LOGIN"
                        enabled: !window.busy && window.loaded && window.current.installed
                        background: Rectangle { color: window.current.frequency === "always" ? "#143245" : "#0c1620"; border.color: window.current.frequency === "always" ? window.bright : window.dim }
                        onClicked: window.apply(["--frequency", "always"])
                    }
                }
                Text {
                    visible: window.scope === "login"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: window.current.frequency === "always"
                        ? "Every login: play the selected video whenever the login screen opens, including after logout. INTRO: OFF still skips it."
                        : "Once per boot: play only on the first login screen after a restart. Returning after logout skips it. Changes to the video do not reset this; use Preview to watch it now."
                    font.family: window.pixel; font.pixelSize: 12; color: window.dim
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 160
                    color: "#05080d"; border.color: window.dim
                    VideoOutput { id: video; anchors.fill: parent; anchors.margins: 1; fillMode: VideoOutput.PreserveAspectFit }
                    Text {
                        anchors.centerIn: parent; visible: player.playbackState !== MediaPlayer.PlayingState
                        text: window.selectedPath ? "VIDEO READY TO PREVIEW" : "CHOOSE YOUR VIDEO"
                        font.family: window.pixel; font.pixelSize: 15; color: window.dim
                    }
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideMiddle
                    text: window.selectedPath || "MP4, WebM, MKV or MOV"
                    font.family: window.pixel; font.pixelSize: 12; color: window.bright
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    IndexButton {
                        Layout.fillWidth: true; text: "CHOOSE VIDEO…"
                        enabled: !window.busy && window.loaded && window.current.installed
                        onClicked: { player.stop(); fileDialog.open() }
                    }
                    IndexButton {
                        text: player.playbackState === MediaPlayer.PlayingState ? "STOP" : "PREVIEW"
                        enabled: !window.busy && window.selectedPath !== ""
                        onClicked: { if (player.playbackState === MediaPlayer.PlayingState) player.stop(); else player.play() }
                    }
                    IndexButton {
                        text: "USE VIDEO"
                        enabled: !window.busy && window.selectedPath !== "" && window.loaded && window.current.installed
                        onClicked: window.apply(["--video", window.selectedPath])
                    }
                }
                IndexButton {
                    Layout.fillWidth: true; text: "USE YOUR ASSETS/INTRO.MP4"
                    enabled: !window.busy && window.loaded && window.current.installed
                    onClicked: window.apply(["--default"])
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Intro videos and login background music are not bundled. Choose your own video here, or add assets/intro.mp4 before setup. The INDEX artwork and sound effects are included."
                    font.family: window.pixel; font.pixelSize: 12; color: window.dim
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: window.message
                    font.family: window.pixel; font.pixelSize: 13
                    color: window.failed ? window.warning : window.bright
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Turn the intro off to go straight to the password screen. Your chosen video is kept."
                    font.family: window.pixel; font.pixelSize: 12; color: window.dim
                }
            }
        }
    }
}
