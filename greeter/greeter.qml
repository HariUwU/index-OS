// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  quickshell greetd greeter
//  Port of the INDEX lock screen (quickshell/lock/lock.qml) to a
//  real login greeter, talking to greetd via Quickshell.Services.Greetd.
// ============================================================
//  REQUIRES: quickshell 0.3.x, QtMultimedia, greetd, cage
//
//  ASSET LAYOUT (all paths relative to this file):
//    greeter.qml
//    assets/PerfectDOSVGA437-Universal.ttf
//    assets/Logo.png
//    assets/DefaultProfile.jpg
//    assets/Power.png
//    assets/Restart.png
//    assets/intro.mp4
//    assets/sounds/{bg.mp3,click.wav,success.wav,fail.wav,check.wav}
//
//  INSTALLED BY new/install-greeter.sh TO:
//    /usr/share/index-greeter/greeter.qml   (+ assets/)
//    /usr/share/index-greeter/user          (one line: the login user)
//
//  RUN (greetd /etc/greetd/config.toml, as the `greeter` user):
//    cage -s -d -- quickshell -p /usr/share/index-greeter/greeter.qml
//
//  NOTES / HONEST CAVEATS:
//   - Quickshell's Greetd service only works when started BY greetd
//     (it talks to $GREETD_SOCK). Run standalone, Greetd.available is
//     false and every login attempt reports ">_GREETD_OFFLINE._".
//   - cage has no layer-shell / session-lock, so this is a plain
//     FloatingWindow (xdg-toplevel) which cage makes full-screen.
//   - One real greetd auth per attempt: createSession(user) ->
//     authMessage(responseRequired) -> respond(password) ->
//     readyToLaunch -> success animation -> launch(plasma).
//   - The FIXER / WILL OF THE CITY modal (after 3 failures) is drama
//     only: its password is just another single greetd attempt.
//     A wrong FIXER password POWERS OFF the machine (the original
//     protocol). Nothing is lost: no session is open at the login screen.
//   - Sounds go through pw-play/paplay/aplay and fail silently (the
//     greeter user often has no sound server). The intro video ends
//     itself on error, startup failure (~2 s), or stalled playback (~6 s).
//   - Esc during the intro skips it (double-click shows >_ SKIP _<).
// ============================================================

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import QtCore
import org.kde.kirigami as Kirigami
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

ShellRoot {
    FloatingWindow {
        id: surf
        visible: true
        title: "INDEX"
        color: "#000000"
        implicitWidth: 1920
        implicitHeight: 1080

        // Fixed hit areas and native symbols keep optional action art usable when absent.
        component OptionalActionIcon: Item {
            id: actionIcon
            property url source
            property bool restart: false
            property color tint: surf.cyanBright
            width: 36; height: 36
            onTintChanged: if (fallback) fallback.requestPaint()
            onRestartChanged: if (fallback) fallback.requestPaint()
            Image {
                id: artwork
                anchors.fill: parent
                source: actionIcon.source
                sourceSize.width: 36; sourceSize.height: 36; smooth: false
                visible: status === Image.Ready
            }
            Canvas {
                id: fallback
                anchors.fill: parent
                visible: artwork.status !== Image.Ready
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = actionIcon.tint
                    ctx.lineWidth = 2.5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    if (actionIcon.restart) {
                        ctx.arc(18, 18, 11, -Math.PI / 2, Math.PI * 1.2)
                        ctx.moveTo(12, 2); ctx.lineTo(18, 7); ctx.lineTo(12, 12)
                    } else {
                        ctx.arc(18, 19, 11, -Math.PI / 2 + 0.65, Math.PI * 1.5 - 0.65)
                        ctx.moveTo(18, 4); ctx.lineTo(18, 17)
                    }
                    ctx.stroke()
                }
            }
        }

        // ---- palette ----
        property color cyan: "#5DADE2"
        property color cyanBright: "#85C5E8"
        property color cyanDim: "#3A7CA5"
        property color warnColor: "#FF6B6B"
        property color successColor: "#5DE285"
        property bool  introActive: introConfig.enabled && introConfig.videoSource.toString() !== ""
        property bool  unlocking: false
        property bool  launching: false

        // ---- state ----
        property int failCount: 0
        property bool passwordCheckRunning: false
        property string currentUsername: "index"

        // drama / greetd routing
        property bool inFinalAuth: false
        property bool authActive: false     // a greetd attempt we own is in flight
        property bool responded: false      // password already sent for this attempt
        property string pendingPassword: ""
        property string authErrorText: ""   // non-password failure (greetd offline/error)
        property bool pamDone: false
        property bool pamSuccess: false
        property bool minElapsed: false

        // session to start on success
        property var sessionCommand: ["/usr/lib/plasma-dbus-run-session-if-needed", "/usr/bin/startplasma-wayland"]
        property var sessionEnv: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=KDE"]

        // size reference for children (window content area)
        Item { id: stage; anchors.fill: parent }

        FontLoader { id: pixelFont; source: Qt.resolvedUrl("assets/PerfectDOSVGA437-Universal.ttf") }

        Settings { id: volSettings; property real volume: 0.5 }
        IntroConfig { id: introConfig }

        // ======================= USER ========================
        // one-line file written by install-greeter.sh; falls back to "index"
        FileView {
            id: userFile
            path: "/usr/share/index-greeter/user"
            printErrors: false
            onLoaded: surf.applyUserFile()
            onLoadFailed: surf.currentUsername = "index"
        }
        function applyUserFile() {
            var t = ""
            try { t = String(userFile.text() || "") } catch (e) { t = "" }
            t = t.split("\n")[0].trim()
            surf.currentUsername = t.length > 0 ? t : "index"
        }

        // KDE account name (System Settings > Users "Name"), like the lock screen shows
        property string displayName: ""
        Process {
            running: surf.currentUsername !== ""
            command: ["getent", "passwd", surf.currentUsername]
            stdout: StdioCollector { onStreamFinished: {
                var f = text.trim().split(":")
                surf.displayName = f.length > 4 ? f[4].split(",")[0].trim() : ""
            } }
        }

        // ======================= AUDIO =======================
        MediaPlayer {
            id: bgMusic
            source: Qt.resolvedUrl("assets/sounds/bg.mp3")
            loops: MediaPlayer.Infinite
            audioOutput: AudioOutput { id: bgAudioOut; volume: 0.5 }
            // Optional user media: clear failed sources so later play() calls stay quiet.
            onErrorOccurred: source = ""
            // NOTE: do NOT auto-play here — it would overlap the intro video audio.
            // bgMusic is started by endIntro() (after the intro) or the no-intro branch.
        }
        // SFX via pw-play/paplay/aplay (PipeWire/Pulse/ALSA). Every branch is
        // silenced and the chain ends in `true`, so no sound server = no noise.
        function sfxPath(f) { return decodeURIComponent(Qt.resolvedUrl("assets/sounds/" + f).toString().replace("file://", "")) }
        function sfx(f) {
            var p = sfxPath(f)
            var v = Math.max(0.0, Math.min(1.0, volTrack.volValue))
            var pa = Math.round(v * 65536)
            Quickshell.execDetached(["sh", "-c",
                '[ -f "$1" ] || exit 0; ' +
                'pw-play --volume="$2" "$1" >/dev/null 2>&1 || ' +
                'paplay --volume="$3" "$1" >/dev/null 2>&1 || ' +
                'aplay -q "$1" >/dev/null 2>&1 || true', "index-sfx", p, v.toFixed(2), String(pa)])
        }
        function playClick()   { sfx("click.wav") }
        function playSuccess() { sfx("success.wav") }
        function playFail()    { sfx("fail.wav") }
        function playCheck()   { sfx("check.wav") }
        NumberAnimation { id: musicFadeOut; target: bgAudioOut; property: "volume"; to: 0.0; duration: 1500 }
        function fadeMusic() { musicFadeOut.start() }

        // ======================= GREETD ======================
        function cancelGreetd() {
            if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        }

        Connections {
            target: Greetd

            function onAuthMessage(message, error, responseRequired, echoResponse) {
                if (!surf.authActive) return
                if (!responseRequired) {
                    if (error) console.log("[index-greeter] greetd auth error message: " + message)
                    else console.log("[index-greeter] greetd auth info: " + message)
                    return
                }
                if (!surf.responded) {
                    surf.responded = true
                    Greetd.respond(surf.pendingPassword)
                } else {
                    // a second prompt (OTP / expired password) — we only have one field
                    console.log("[index-greeter] unexpected second prompt: " + message)
                    surf.cancelGreetd()
                    surf.finishAuth(false, "")
                }
            }
            function onReadyToLaunch() {
                if (!surf.authActive) return
                surf.finishAuth(true, "")
            }
            function onAuthFailure(message) {
                if (!surf.authActive) return
                console.log("[index-greeter] auth failure: " + message)
                surf.cancelGreetd()
                surf.finishAuth(false, "")
            }
            function onError(error) {
                console.log("[index-greeter] greetd error: " + error)
                if (surf.launching) { surf.launchFailed(); return }
                if (!surf.authActive) return
                surf.cancelGreetd()
                surf.finishAuth(false, ">_GREETD_ERROR._")
            }
        }

        function beginAuth(finalAuth) {
            surf.inFinalAuth = finalAuth
            surf.pamDone = false
            surf.pamSuccess = false
            surf.minElapsed = false
            surf.authErrorText = ""
            surf.responded = false
            surf.pendingPassword = finalAuth ? defensePassword.text : passwordInput.text
            dramaTimer.restart()
            if (!Greetd.available) {
                surf.authActive = false
                surf.pamDone = true
                surf.pamSuccess = false
                surf.authErrorText = ">_GREETD_OFFLINE._"
                return
            }
            surf.cancelGreetd()
            surf.authActive = true
            Greetd.createSession(surf.currentUsername)
        }
        function finishAuth(ok, errText) {
            surf.authActive = false
            surf.pendingPassword = ""
            surf.authErrorText = errText
            surf.pamDone = true
            surf.pamSuccess = ok
            surf.tryResolve()
        }
        function tryResolve() {
            if (surf.pamDone && surf.minElapsed) {
                surf.pamDone = false
                if (surf.inFinalAuth) applyFinalResult(surf.pamSuccess)
                else applyResult(surf.pamSuccess)
            }
        }
        // minimum 1200ms so the scramble animation always reads
        Timer { id: dramaTimer; interval: 1200; repeat: false
            onTriggered: { surf.minElapsed = true; surf.tryResolve() } }

        function launchSession() {
            if (Greetd.state !== GreetdState.ReadyToLaunch) { surf.launchFailed(); return }
            surf.launching = true
            Greetd.launch(surf.sessionCommand, surf.sessionEnv)   // quits quickshell on success
        }
        // launch rejected -> undo the fade and go back to the prompt
        function launchFailed() {
            surf.launching = false
            surf.unlocking = false
            surf.cancelGreetd()
            successFade.stop(); musicFadeOut.stop()
            fadeOverlay.opacity = 0.0
            bgAudioOut.volume = volTrack.volValue
            if (defenseModal.visible) { defenseModal.opacity = 0.0; defenseModal.visible = false }
            surf.failCount = 0
            surf.passwordCheckRunning = true
            scrambleDisplay.text = "_LAUNCH_FAILED._"; scrambleDisplay.color = surf.warnColor
            statusMessage.text = ">_SESSION_LAUNCH_FAILED._"; statusMessage.color = surf.warnColor
            playFail()
            if (bgMusic.playbackState !== MediaPlayer.PlayingState) bgMusic.play()
            resetTimer.restart()
        }

        // ======================= OVERLAYS ====================
        // CRT scanlines
        Item {
            anchors.fill: parent; z: 100; opacity: 0.15
            Repeater {
                model: Math.floor(stage.height / 4)
                Rectangle { width: stage.width; height: 2; y: index * 4 + 2; color: "#000000" }
            }
        }
        // vignette
        Rectangle {
            anchors.fill: parent; z: 99
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#80000000" }
                GradientStop { position: 0.5; color: "#00000000" }
                GradientStop { position: 1.0; color: "#80000000" }
            }
        }
        // boot fade-in / session fade
        Rectangle {
            id: fadeOverlay
            anchors.fill: parent; color: "#000000"; z: 999; opacity: 1.0
            NumberAnimation on opacity { from: 1.0; to: 0.0; duration: 1500; easing.type: Easing.InOutQuad; running: true }
        }
        NumberAnimation { id: successFade; target: fadeOverlay; property: "opacity"; from: 0.0; to: 1.0; duration: 800; easing.type: Easing.InQuad }

        // ======================= CINEMATIC INTRO (VIDEO) =====
        Item {
            id: introLayer
            anchors.fill: parent; z: 1000
            visible: opacity > 0.001
            opacity: surf.introActive ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InQuad } }

            // keyboard during the intro: Esc skips, any other key reveals SKIP
            Keys.onPressed: (event) => {
                if (!surf.introActive) return
                if (event.key === Qt.Key_Escape) surf.skipIntro()
                else { skipBtn.visible = true; skipHideTimer.restart() }
                event.accepted = true
            }

            Rectangle { anchors.fill: parent; color: "#000000" }

            MediaPlayer {
                id: introVideo
                source: surf.introActive ? introConfig.videoSource : ""
                videoOutput: introVideoOut
                audioOutput: AudioOutput { id: introVidAudio; volume: surf.introActive ? 0.9 : 0 }
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.EndOfMedia || mediaStatus === MediaPlayer.InvalidMedia)
                        Qt.callLater(surf.endIntro)  // wait until all focus/audio objects exist
                }
                onErrorOccurred: Qt.callLater(surf.endIntro)
                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PausedState)
                        introWatchdog.resetProgress()
                }
            }
            VideoOutput {
                id: introVideoOut
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            // Allow ~2 s to start, then ~6 s without progress. Explicit
            // pauses reset the budget, including pauses between timer ticks.
            Timer {
                id: introWatchdog; interval: 500; repeat: true
                property int lastPosition: 0
                property int idleMs: 0
                property bool hasProgress: false
                function resetProgress() {
                    introWatchdog.lastPosition = introVideo.position
                    introWatchdog.idleMs = 0
                }
                function checkProgress() {
                    if (!surf.introActive) return
                    if (introVideo.playbackState === MediaPlayer.PausedState) {
                        introWatchdog.resetProgress()
                        return
                    }
                    if (introVideo.playbackState === MediaPlayer.PlayingState &&
                        introVideo.position > introWatchdog.lastPosition) {
                        introWatchdog.hasProgress = true
                        introWatchdog.idleMs = 0
                    } else {
                        introWatchdog.idleMs += introWatchdog.interval
                    }
                    introWatchdog.lastPosition = introVideo.position
                    if (introWatchdog.idleMs >= (introWatchdog.hasProgress ? 6000 : 2000))
                        surf.endIntro()
                }
                onTriggered: introWatchdog.checkProgress()
            }

            // double-click anywhere -> reveal the skip button
            MouseArea {
                anchors.fill: parent
                onDoubleClicked: { skipBtn.visible = true; skipHideTimer.restart() }
            }
            Timer { id: skipHideTimer; interval: 2500; repeat: false
                onTriggered: skipBtn.visible = false }

            // SKIP button, top-right, hidden until double-click
            Rectangle {
                id: skipBtn
                visible: false
                anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 26
                width: skipTxt.implicitWidth + 28; height: 38
                color: skipArea.containsMouse ? "#143245" : "#0a0e16"
                border.color: "#5DADE2"; border.width: 2
                z: 10
                Text {
                    id: skipTxt; anchors.centerIn: parent
                    text: ">_ SKIP _<"
                    font.family: pixelFont.name; font.pixelSize: 18
                    color: skipArea.containsMouse ? "#FFFFFF" : "#85C5E8"
                }
                MouseArea {
                    id: skipArea; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: surf.skipIntro()
                }
            }

            Timer { id: introFocusTimer; interval: 600; repeat: false
                onTriggered: passwordInput.forceActiveFocus() }
        }

        // intro control helpers
        function startIntro() {
            if (introVideo.mediaStatus === MediaPlayer.InvalidMedia || introVideo.error !== MediaPlayer.NoError) {
                surf.endIntro()
                return
            }
            bgMusic.stop()              // fully stop the music during the intro
            introLayer.forceActiveFocus()
            introWatchdog.start()
            introVideo.play()
        }
        function endIntro() {
            if (!surf.introActive) return
            introWatchdog.stop()
            surf.introActive = false
            introVideo.stop()
            bgAudioOut.volume = volTrack.volValue
            bgMusic.play()              // start the greeter music now that the intro is done
            passwordInput.forceActiveFocus()
            introFocusTimer.start()     // re-assert focus once the fade settles
        }
        function skipIntro() {
            endIntro()
            passwordInput.forceActiveFocus()
        }

        // ======================= MAIN UI =====================
        RowLayout {
            anchors.centerIn: parent
            width: Math.min(stage.width * 0.8, 1100)
            spacing: 60
            opacity: surf.introActive ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

            // left column: clock + logo
            ColumnLayout {
                spacing: 40
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignLeft
                    font.family: pixelFont.name
                    font.pixelSize: 56
                    color: surf.cyanBright
                    style: Text.Outline; styleColor: surf.cyan
                    text: "_06:07 AM._"
                }
                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: {
                        var n = new Date(); var h = n.getHours(); var m = n.getMinutes()
                        var ap = h >= 12 ? "PM" : "AM"; h = h % 12 || 12
                        clockText.text = "_" + (h<10?"0"+h:h) + ":" + (m<10?"0"+m:m) + " " + ap + "._"
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 240; Layout.preferredHeight: 240
                    text: logoImage.status === Image.Ready ? "" : ">_INDEX"
                    color: surf.cyanBright
                    font.family: pixelFont.name; font.pixelSize: 40
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    Image {
                        id: logoImage
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/Logo.png")
                        sourceSize.width: 240; sourceSize.height: 240
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                }
            }

            // right column: profile/user, password, login
            ColumnLayout {
                spacing: 18
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true

                RowLayout {
                    spacing: 10; Layout.fillWidth: true
                    Rectangle {
                        width: 70; height: 70; color: "transparent"
                        border.color: surf.cyan; border.width: 2
                        Image {
                            id: accountPhoto
                            anchors.fill: parent; anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop; smooth: false
                            // KDE account picture (System Settings > Users saves it via
                            // AccountsService, readable before login).
                            source: surf.currentUsername
                                    ? "file:///var/lib/AccountsService/icons/" + surf.currentUsername : ""
                            cache: false
                            visible: status === Image.Ready
                        }
                        Kirigami.Icon {
                            anchors.fill: parent; anchors.margins: 10
                            // greetd has no user icon theme. Load KDE's stock
                            // Breeze symbol directly rather than resolving a theme name.
                            source: "file:///usr/share/icons/breeze/places/24/user-identity.svg"
                            isMask: true
                            color: surf.cyanBright
                            visible: accountPhoto.status !== Image.Ready
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 60; color: "transparent"
                        border.color: surf.cyan; border.width: 2
                        Text {
                            anchors.fill: parent; anchors.margins: 14
                            font.family: pixelFont.name; font.pixelSize: 24
                            color: surf.cyanBright; verticalAlignment: Text.AlignVCenter
                            text: "_" + (surf.displayName || surf.currentUsername).toUpperCase() + "._"
                        }
                    }
                }

                RowLayout {
                    spacing: 14; Layout.leftMargin: 80; Layout.fillWidth: true
                    Rectangle {
                        Layout.fillWidth: true; height: 50; color: "transparent"
                        border.color: surf.passwordCheckRunning ? surf.warnColor : surf.cyan
                        border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        TextInput {
                            id: passwordInput
                            anchors.fill: parent; anchors.margins: 12
                            font.family: pixelFont.name; font.pixelSize: 22
                            color: surf.cyanBright
                            echoMode: TextInput.Password; passwordCharacter: "."
                            verticalAlignment: TextInput.AlignVCenter
                            visible: !surf.passwordCheckRunning
                            Keys.onReturnPressed: surf.doLogin()
                            Keys.onEnterPressed: surf.doLogin()
                        }
                        Text {
                            id: scrambleDisplay
                            anchors.fill: parent; anchors.margins: 12
                            font.family: pixelFont.name; font.pixelSize: 22
                            color: surf.warnColor; verticalAlignment: Text.AlignVCenter
                            visible: surf.passwordCheckRunning
                        }
                    }
                }

                Text {
                    id: statusMessage
                    Layout.leftMargin: 80
                    font.family: pixelFont.name; font.pixelSize: 18
                    color: surf.cyan; text: ""; visible: text.length > 0
                }

                Text {
                    Layout.leftMargin: 80; Layout.topMargin: 8
                    text: "<_Login._>"
                    font.family: pixelFont.name; font.pixelSize: 26
                    color: loginMouseArea.containsMouse ? "white" : surf.cyanBright
                    opacity: surf.passwordCheckRunning ? 0.4 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: loginMouseArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !surf.passwordCheckRunning
                        onClicked: { surf.playClick(); surf.doLogin() }
                    }
                }
            }
        }

        // ======================= VOLUME ======================
        Row {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            anchors.leftMargin: 30; anchors.bottomMargin: 36; spacing: 10; z: 50
            Text { anchors.verticalCenter: parent.verticalCenter; text: "VOL"
                font.family: pixelFont.name; font.pixelSize: 14; color: surf.cyanDim }
            Item {
                id: volTrack
                anchors.verticalCenter: parent.verticalCenter; width: 120; height: 20
                property real volValue: 0.5
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: surf.cyanDim }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: volTrack.volValue * parent.width; height: 2; color: surf.cyan }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; x: volTrack.volValue * (volTrack.width - width); width: 10; height: 10; color: surf.cyan; rotation: 45 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    function apply(mx) {
                        var v = Math.max(0.0, Math.min(1.0, mx / volTrack.width))
                        volTrack.volValue = v; bgAudioOut.volume = v
                        volSettings.volume = v
                    }
                    onPressed: (m) => apply(m.x)
                    onPositionChanged: (m) => { if (pressed) apply(m.x) }
                }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(volTrack.volValue * 100) + "%"
                font.family: pixelFont.name; font.pixelSize: 14; color: surf.cyanDim; width: 36 }
        }

        // ======================= POWER / RESTART =============
        Row {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: 30; anchors.bottomMargin: 30; spacing: 16; z: 50
            OptionalActionIcon {
                source: Qt.resolvedUrl("assets/Power.png")
                scale: sA.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 150 } }
                MouseArea { id: sA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { surf.playClick(); Quickshell.execDetached(["systemctl", "poweroff"]) } }
            }
            OptionalActionIcon {
                source: Qt.resolvedUrl("assets/Restart.png")
                restart: true
                scale: rA.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 150 } }
                MouseArea { id: rA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { surf.playClick(); Quickshell.execDetached(["systemctl", "reboot"]) } }
            }
        }

        // ======================= LOGIN LOGIC =================
        property string scrambleChars: "!@#$%^&*()_+-=[]{}|;:,.<>?/~`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        function generateScrambleText(len) {
            var r = ""
            for (var i = 0; i < len; i++) r += scrambleChars.charAt(Math.floor(Math.random() * scrambleChars.length))
            return r
        }
        Timer { id: scrambleTimer; interval: 50; repeat: true; running: false
            onTriggered: scrambleDisplay.text = "_" + surf.generateScrambleText(12) + "._" }

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x - 10; duration: 50 }
            NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x + 10; duration: 50 }
            NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x; duration: 50 }
        }

        function doLogin() {
            if (surf.passwordCheckRunning || surf.unlocking || surf.introActive) return
            if (passwordInput.text.length === 0) { shakeAnim.start(); passwordInput.forceActiveFocus(); return }
            surf.passwordCheckRunning = true
            statusMessage.text = ">_CHECKING._"; statusMessage.color = surf.cyan
            scrambleDisplay.color = surf.warnColor
            scrambleTimer.start(); playCheck()
            delayedVerify.restart()
            beginAuth(false)
        }
        Timer { id: delayedVerify; interval: 600; repeat: false
            onTriggered: statusMessage.text = ">_VERIFYING._" }

        function applyResult(ok) {
            scrambleTimer.stop(); delayedVerify.stop()
            if (ok) {
                // cancel any queued deny sequence from earlier attempts
                answerTypeTimer.stop(); afterDenyTimer.stop(); defenseModalTrigger.stop()
                surf.unlocking = true
                scrambleDisplay.text = "_ACCESS_GRANTED._"; scrambleDisplay.color = surf.successColor
                statusMessage.text = ">_LOGIN_SUCCESS._"; statusMessage.color = surf.successColor
                playSuccess(); fadeMusic(); unlockTimer.start()
            } else {
                scrambleDisplay.text = "_ACCESS_DENIED._"; scrambleDisplay.color = surf.warnColor
                playFail()
                if (surf.authErrorText.length > 0) {
                    // greetd problem, not a wrong password: don't count it
                    statusMessage.text = surf.authErrorText; statusMessage.color = surf.warnColor
                    resetTimer.start()
                } else {
                    surf.failCount += 1
                    statusMessage.text = ">_WRONG_PASSWORD._"; statusMessage.color = surf.warnColor
                    if (surf.failCount >= 3) defenseModalTrigger.start()
                    else resetTimer.start()
                }
            }
        }
        Timer { id: resetTimer; interval: 1500; repeat: false; onTriggered: {
            surf.passwordCheckRunning = false; passwordInput.text = ""
            passwordInput.forceActiveFocus(); statusMessage.text = ""
            if (surf.failCount < 3) defenseModalTrigger.stop()
        } }
        Timer { id: unlockTimer; interval: 900; repeat: false; onTriggered: {
            successFade.start(); finalUnlock.start()
        } }
        // fade done -> hand the authenticated session to greetd
        Timer { id: finalUnlock; interval: 850; repeat: false; onTriggered: surf.launchSession() }
        Timer { id: defenseModalTrigger; interval: 1800; repeat: false; onTriggered: defenseModal.startSequence() }

        // ======================= WILL OF THE CITY MODAL ======
        Rectangle {
            id: defenseModal
            anchors.fill: parent; color: "#000000"; z: 500
            visible: false; opacity: 0.0
            Behavior on opacity { NumberAnimation { duration: 400 } }

            property string answerText: "◆ The City's will is absolute. There is no negotiation."
            property var warningSegments: [
                { text: "The ", color: "#FFFFFF" },
                { text: "Head", color: "#FFD700" },
                { text: " has issued a decree.\nUnauthorized access detected in ", color: "#FFFFFF" },
                { text: "the City", color: "#FFA500" },
                { text: ".\n\n", color: "#FFFFFF" },
                { text: "By the Will of the City,\nthis terminal will alert the nearby\n", color: "#FFFFFF" },
                { text: "Index Proxy", color: "#f3f1eb" },
                { text: " and ", color: "#FFFFFF" },
                { text: "[REDACTED]", color: "#FF3333" },
                { text: ".", color: "#FFFFFF" }
            ]
            property int warningLen: {
                var t = 0; for (var i = 0; i < warningSegments.length; i++) t += warningSegments[i].text.length; return t
            }
            property int typeIndex: 0

            function startSequence() {
                visible = true; opacity = 1.0
                surf.passwordCheckRunning = false   // 3-fail path left this true -> modal input was disabled
                typeIndex = 0; warningTypeText.text = ""
                answerLine.visible = false; answerLine.text = ""
                finalInputArea.visible = false; defensePassword.text = ""
                defenseStatus.text = ""
                bgMusic.stop()
                defenseModal.forceActiveFocus()     // keep keystrokes out of the hidden main field
                typewriterTimer.start()
            }

            Rectangle { anchors.fill: parent; color: "#CC000000" }
            // swallow clicks so the main UI underneath can't be used
            MouseArea { anchors.fill: parent; hoverEnabled: true }

            Rectangle {
                anchors.centerIn: parent; width: 820; height: 520
                color: "#000000"; border.color: surf.warnColor; border.width: 2

                Text { text: "╔"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6 }
                Text { text: "╗"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6 }
                Text { text: "╚"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 6 }
                Text { text: "╝"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 6 }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 40; spacing: 20

                    Text {
                        text: ">_ WILL OF THE CITY _<"
                        font.family: pixelFont.name; font.pixelSize: 20; color: surf.warnColor
                        Layout.alignment: Qt.AlignHCenter
                        SequentialAnimation on opacity {
                            running: defenseModal.visible; loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                        }
                    }
                    Rectangle { height: 1; Layout.fillWidth: true; color: surf.warnColor; opacity: 0.5 }
                    Text {
                        id: warningTypeText
                        Layout.fillWidth: true
                        font.family: pixelFont.name; font.pixelSize: 22
                        wrapMode: Text.WordWrap; textFormat: Text.RichText; lineHeight: 1.4; text: ""
                    }
                    Text {
                        id: answerLine
                        visible: false; Layout.fillWidth: true
                        font.family: pixelFont.name; font.pixelSize: 22; color: "#FFD700"
                        wrapMode: Text.WordWrap; text: ""
                    }
                    Item { Layout.fillHeight: true }

                    ColumnLayout {
                        id: finalInputArea
                        visible: false; Layout.fillWidth: true; spacing: 10
                        Text { text: ">_ FIXER AUTHORIZATION REQUIRED:_"
                            font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor }
                        RowLayout {
                            spacing: 12; Layout.fillWidth: true
                            Rectangle {
                                Layout.fillWidth: true; height: 46; color: "transparent"
                                border.color: surf.passwordCheckRunning ? surf.warnColor : surf.cyan; border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                TextInput {
                                    id: defensePassword
                                    anchors.fill: parent; anchors.margins: 10
                                    font.family: pixelFont.name; font.pixelSize: 20; color: surf.cyanBright
                                    echoMode: TextInput.Password; passwordCharacter: "."
                                    verticalAlignment: TextInput.AlignVCenter
                                    enabled: !surf.passwordCheckRunning
                                    Keys.onReturnPressed: surf.doFinalLogin()
                                    Keys.onEnterPressed: surf.doFinalLogin()
                                }
                            }
                            Text {
                                text: "<_AUTHORIZE._>"
                                font.family: pixelFont.name; font.pixelSize: 20
                                color: finalExecArea.containsMouse ? "white" : surf.warnColor
                                Behavior on color { ColorAnimation { duration: 150 } }
                                opacity: surf.passwordCheckRunning ? 0.4 : 1.0
                                MouseArea { id: finalExecArea; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; enabled: !surf.passwordCheckRunning
                                    onClicked: { surf.playClick(); surf.doFinalLogin() } }
                            }
                        }
                        Text { id: defenseStatus; font.family: pixelFont.name; font.pixelSize: 17
                            color: surf.warnColor; text: ""; visible: text.length > 0 }
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 38; repeat: true; running: false
                onTriggered: {
                    if (defenseModal.typeIndex < defenseModal.warningLen) {
                        defenseModal.typeIndex++
                        var html = ""; var left = defenseModal.typeIndex
                        var segs = defenseModal.warningSegments
                        for (var i = 0; i < segs.length && left > 0; i++) {
                            var portion = segs[i].text.substring(0, left).replace(/\n/g, "<br>")
                            html += "<font color='" + segs[i].color + "'>" + portion + "</font>"
                            left -= segs[i].text.length
                        }
                        warningTypeText.text = html
                    } else {
                        typewriterTimer.stop(); showInputTimer.start()
                    }
                }
            }
            Timer { id: showInputTimer; interval: 600; repeat: false
                onTriggered: { finalInputArea.visible = true; defensePassword.forceActiveFocus() } }
        }

        function doFinalLogin() {
            if (surf.passwordCheckRunning || surf.unlocking) return
            if (answerTypeTimer.running || afterDenyTimer.running || modalCloseTimer.running) return
            if (defensePassword.text.length === 0) return
            surf.passwordCheckRunning = true
            defenseStatus.text = ">_VERIFYING FIXER CREDENTIALS._"; defenseStatus.color = surf.cyan
            playCheck()
            beginAuth(true)
        }
        function applyFinalResult(ok) {
            surf.passwordCheckRunning = false
            if (ok) {
                // cancel anything a previous failed attempt queued
                answerTypeTimer.stop(); afterDenyTimer.stop(); modalCloseTimer.stop()
                answerLine.visible = false
                defenseStatus.text = ">_AUTHORIZATION GRANTED. Welcome, Fixer._"; defenseStatus.color = surf.successColor
                playSuccess(); fadeMusic()
                surf.unlocking = true
                successFade.start(); finalUnlock.start()
            } else {
                defensePassword.text = ""
                surf.fixerDenied = surf.authErrorText.length === 0
                defenseStatus.text = surf.authErrorText.length > 0
                    ? surf.authErrorText
                    : ">_AUTHORIZATION DENIED._"
                defenseStatus.color = surf.warnColor
                playFail()
                answerLine.visible = true; surf.answerIdx = 0; answerLine.text = ""
                answerTypeTimer.start()
            }
        }

        // Wrong WILL OF THE CITY / Fixer password -> the City's answer,
        // then the original protocol: fade to black and POWER OFF.
        // (A greetd/technical error is not the user's fault: back to the prompt.)
        property bool fixerDenied: false
        property int answerIdx: 0
        Timer {
            id: answerTypeTimer
            interval: 45; repeat: true; running: false
            onTriggered: {
                if (surf.answerIdx < defenseModal.answerText.length) {
                    answerLine.text += defenseModal.answerText.charAt(surf.answerIdx); surf.answerIdx++
                } else {
                    answerTypeTimer.stop(); afterDenyTimer.start()
                }
            }
        }
        Timer {
            id: afterDenyTimer
            interval: 2200; repeat: false
            onTriggered: {
                if (surf.unlocking) return
                defenseModal.opacity = 0.0
                if (surf.fixerDenied) {
                    fadeMusic(); successFade.start()
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    return
                }
                modalCloseTimer.start()
            }
        }
        Timer { id: modalCloseTimer; interval: 450; repeat: false; onTriggered: {
            if (surf.unlocking) return
            defenseModal.visible = false
            surf.failCount = 0
            surf.passwordCheckRunning = false
            passwordInput.text = ""; statusMessage.text = ""
            scrambleDisplay.text = ""
            bgAudioOut.volume = volTrack.volValue
            bgMusic.play()
            passwordInput.forceActiveFocus()
        } }

        Component.onCompleted: {
            if (userFile.loaded) surf.applyUserFile()
            var v = volSettings.volume
            volTrack.volValue = v; bgAudioOut.volume = v
            // The launcher grants one attempt per boot, for original or custom video.
            // Missing boot eligibility skips boot-only playback (including direct previews).
            var play = surf.introActive && !introConfig.oncePerBoot
            try {
                play = surf.introActive && (!introConfig.oncePerBoot ||
                    String(Quickshell.env("INDEX_INTRO_BOOT")) === "1")
                var flag = Quickshell.env("INDEX_INTRO")
                if (flag !== undefined && flag !== null && String(flag) !== "")
                    play = play && (String(flag) === "1")
            } catch (e) { /* env API missing -> skip boot-only intro */ }
            if (play) startIntro()
            else { surf.introActive = false; bgMusic.play(); passwordInput.forceActiveFocus(); introFocusTimer.start() }
        }
    }
}
