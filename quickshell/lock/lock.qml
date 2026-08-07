// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  quickshell session lock
//  Port of the terminal SDDM theme to a real Wayland locker.
// ============================================================
//  REQUIRES: quickshell (AUR: quickshell-git), QtMultimedia
//
//  ASSET LAYOUT (same as your SDDM theme):
//    lock.qml
//    assets/PerfectDOSVGA437.ttf
//    assets/Logo.png
//    assets/DefaultProfile.jpg
//    assets/Power.png
//    assets/Restart.png
//    assets/sounds/{bg.mp3,click.wav,success.wav,fail.wav,check.wav}
//
//  TEST (won't lock you out — Esc-safe only if you trust it; use a TTY first):
//    quickshell -p ./lock.qml
//
//  WIRE TO hypridle ( ~/.config/hypr/hypridle.conf ):
//    general { lock_cmd = pgrep -f lock/lock.qml || quickshell -p ~/.config/quickshell/lock/lock.qml }
//    (guard on the lock's command line — NOT `pidof quickshell`, since the
//     bar/atmosphere also run quickshell and would make that always true.)
//
//  NOTES / HONEST CAVEATS:
//   - The Quickshell.Services.Pam API has shifted across versions. If auth
//     does nothing, check `qs --version` and the Pam docs; the flow here uses
//     start() -> responseRequired -> respond() -> completed(result).
//   - Caps-lock indicator from SddmComponents is gone (no equivalent); dropped.
//   - Built for the primary monitor. Multi-monitor: each WlSessionLockSurface
//     is separate — you'd lift state into the WlSessionLock and only accept
//     input on the focused screen. Left simple on purpose.
//   - Failed FIXER auth does NOT power off (that would kill your live session +
//     unsaved work). It resets to the lock. A real poweroff hook is included
//     but commented out — enable at your own risk.
// ============================================================

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            id: surf
            color: "#000000"

            // ---- palette ----
            property color cyan: "#5DADE2"
            property color cyanBright: "#85C5E8"
            property color cyanDim: "#3A7CA5"
            property color warnColor: "#FF6B6B"
            property color successColor: "#5DE285"
            property bool  introActive: true

            // ---- state ----
            property int failCount: 0
            property bool passwordCheckRunning: false
            property string currentUsername: Quickshell.env("USER") || "user"

            // drama / pam routing
            property bool inFinalAuth: false
            property bool pamDone: false
            property bool pamSuccess: false
            property bool minElapsed: false

            FontLoader { id: pixelFont; source: Qt.resolvedUrl("assets/PerfectDOSVGA437.ttf") }

            Settings { id: volSettings; property real volume: 0.5 }

            // ======================= AUDIO =======================
            MediaPlayer {
                id: bgMusic
                source: Qt.resolvedUrl("assets/sounds/bg.mp3")
                loops: MediaPlayer.Infinite
                audioOutput: AudioOutput { id: bgAudioOut; volume: 0.5 }
                // NOTE: do NOT auto-play here — it would overlap the intro video audio.
                // bgMusic is started by endIntro() (after the intro) or the no-intro branch.
            }
            SoundEffect { id: clickSound;   source: Qt.resolvedUrl("assets/sounds/click.wav");   volume: 0.8 }
            SoundEffect { id: successSound; source: Qt.resolvedUrl("assets/sounds/success.wav"); volume: 0.9 }
            SoundEffect { id: failSound;    source: Qt.resolvedUrl("assets/sounds/fail.wav");    volume: 0.9 }
            SoundEffect { id: checkSound;   source: Qt.resolvedUrl("assets/sounds/check.wav");   volume: 0.8 }
            // SoundEffect is flaky on Wayland lock surfaces -> play via pw-play/paplay (PipeWire)
            function sfxPath(f) { return Qt.resolvedUrl("assets/sounds/" + f).toString().replace("file://", "") }
            function sfx(f) { Quickshell.execDetached(["sh","-c","pw-play '"+sfxPath(f)+"' 2>/dev/null || paplay '"+sfxPath(f)+"' 2>/dev/null || aplay '"+sfxPath(f)+"' 2>/dev/null"]) }
            function playClick()   { sfx("click.wav") }
            function playSuccess() { sfx("success.wav") }
            function playFail()    { sfx("fail.wav") }
            function playCheck()   { sfx("check.wav") }
            NumberAnimation { id: musicFadeOut; target: bgAudioOut; property: "volume"; to: 0.0; duration: 1500 }
            function fadeMusic() { musicFadeOut.start() }

            // ======================= PAM =========================
            PamContext {
                id: pam
                config: "login"
                user: surf.currentUsername

                onResponseRequiredChanged: {
                    if (responseRequired)
                        respond(surf.inFinalAuth ? defensePassword.text : passwordInput.text)
                }
                onCompleted: function(result) {
                    surf.pamDone = true
                    surf.pamSuccess = (result === PamResult.Success)
                    surf.tryResolve()
                }
            }

            function beginAuth(finalAuth) {
                surf.inFinalAuth = finalAuth
                surf.pamDone = false
                surf.pamSuccess = false
                surf.minElapsed = false
                dramaTimer.restart()
                pam.start()
            }
            function tryResolve() {
                if (surf.pamDone && surf.minElapsed) {
                    if (surf.inFinalAuth) applyFinalResult(surf.pamSuccess)
                    else applyResult(surf.pamSuccess)
                }
            }
            // minimum 1200ms so the scramble animation always reads
            Timer { id: dramaTimer; interval: 1200; repeat: false
                onTriggered: { surf.minElapsed = true; surf.tryResolve() } }

            // ======================= OVERLAYS ====================
            // CRT scanlines
            Item {
                anchors.fill: parent; z: 100; opacity: 0.15
                Repeater {
                    model: Math.floor(surf.height / 4)
                    Rectangle { width: surf.width; height: 2; y: index * 4 + 2; color: "#000000" }
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
            // boot fade-in / shutdown fade
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
                opacity: 1.0
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InQuad } }

                Rectangle { anchors.fill: parent; color: "#000000" }

                // your local intro video — drop assets/intro.mp4 (NOT shipped in repo)
                MediaPlayer {
                    id: introVideo
                    source: Qt.resolvedUrl("assets/intro.mp4")
                    videoOutput: introVideoOut
                    audioOutput: AudioOutput { id: introVidAudio; volume: 0.9 }
                    onMediaStatusChanged: {
                        if (mediaStatus === MediaPlayer.EndOfMedia) surf.endIntro()
                        if (mediaStatus === MediaPlayer.InvalidMedia) surf.endIntro()  // no video -> skip
                    }
                    onErrorOccurred: surf.endIntro()
                }
                VideoOutput {
                    id: introVideoOut
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
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
                bgMusic.stop()              // fully stop the lock music during the intro
                introVideo.play()
            }
            function endIntro() {
                surf.introActive = false
                introLayer.opacity = 0.0
                introVideo.stop()
                bgAudioOut.volume = volSettings.volume
                bgMusic.play()              // start the lock music now that the intro is done
                introFocusTimer.start()
            }
            function skipIntro() { endIntro() }

            // ======================= MAIN UI =====================
            RowLayout {
                anchors.centerIn: parent
                width: Math.min(surf.width * 0.8, 1100)
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
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: Qt.resolvedUrl("assets/Logo.png")
                        sourceSize.width: 240; sourceSize.height: 240
                        fillMode: Image.PreserveAspectFit
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
                                anchors.fill: parent; anchors.margins: 2
                                fillMode: Image.PreserveAspectCrop; smooth: false
                                source: Qt.resolvedUrl("assets/DefaultProfile.jpg")
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 60; color: "transparent"
                            border.color: surf.cyan; border.width: 2
                            Text {
                                anchors.fill: parent; anchors.margins: 14
                                font.family: pixelFont.name; font.pixelSize: 24
                                color: surf.cyanBright; verticalAlignment: Text.AlignVCenter
                                text: "_" + surf.currentUsername.toUpperCase() + "._"
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
                                focus: true; visible: !surf.passwordCheckRunning
                                Keys.onReturnPressed: doLogin()
                                Keys.onEnterPressed: doLogin()
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
                            onClicked: { playClick(); doLogin() }
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
                            clickSound.volume = v; successSound.volume = v; failSound.volume = v; checkSound.volume = v
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
                Image {
                    source: Qt.resolvedUrl("assets/Power.png")
                    sourceSize.width: 36; sourceSize.height: 36; smooth: false
                    scale: sA.containsMouse ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    MouseArea { id: sA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { playClick(); Quickshell.execDetached(["systemctl", "poweroff"]) } }
                }
                Image {
                    source: Qt.resolvedUrl("assets/Restart.png")
                    sourceSize.width: 36; sourceSize.height: 36; smooth: false
                    scale: rA.containsMouse ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    MouseArea { id: rA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { playClick(); Quickshell.execDetached(["systemctl", "reboot"]) } }
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
                onTriggered: scrambleDisplay.text = "_" + generateScrambleText(12) + "._" }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x - 10; duration: 50 }
                NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x + 10; duration: 50 }
                NumberAnimation { target: passwordInput; property: "x"; to: passwordInput.x; duration: 50 }
            }

            function doLogin() {
                if (surf.passwordCheckRunning) return
                if (passwordInput.text.length === 0) { shakeAnim.start(); passwordInput.forceActiveFocus(); return }
                surf.passwordCheckRunning = true
                statusMessage.text = ">_CHECKING._"; statusMessage.color = surf.cyan
                scrambleTimer.start(); playCheck()
                delayedVerify.restart()
                beginAuth(false)
            }
            Timer { id: delayedVerify; interval: 600; repeat: false
                onTriggered: statusMessage.text = ">_VERIFYING._" }

            function applyResult(ok) {
                scrambleTimer.stop()
                if (ok) {
                    scrambleDisplay.text = "_ACCESS_GRANTED._"; scrambleDisplay.color = surf.successColor
                    statusMessage.text = ">_LOGIN_SUCCESS._"; statusMessage.color = surf.successColor
                    playSuccess(); fadeMusic(); unlockTimer.start()
                } else {
                    scrambleDisplay.text = "_ACCESS_DENIED._"; scrambleDisplay.color = surf.warnColor
                    playFail(); surf.failCount += 1
                    statusMessage.text = ">_WRONG_PASSWORD._"; statusMessage.color = surf.warnColor
                    if (surf.failCount >= 3) defenseModalTrigger.start()
                    else resetTimer.start()
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
            Timer { id: finalUnlock; interval: 850; repeat: false; onTriggered: {
                sessionLock.locked = false; Qt.quit()
            } }
            Timer { id: defenseModalTrigger; interval: 1800; repeat: false; onTriggered: defenseModal.startSequence() }

            // ======================= WILL OF THE CITY MODAL ======
            Rectangle {
                id: defenseModal
                anchors.fill: parent; color: "#000000"; z: 500
                visible: false; opacity: 0.0
                Behavior on opacity { NumberAnimation { duration: 400 } }

                property string answerText: "\u25C6 The City's will is absolute. There is no negotiation."
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
                    typewriterTimer.start()
                }

                Rectangle { anchors.fill: parent; color: "#CC000000" }

                Rectangle {
                    anchors.centerIn: parent; width: 820; height: 520
                    color: "#000000"; border.color: surf.warnColor; border.width: 2

                    Text { text: "\u2554"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6 }
                    Text { text: "\u2557"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6 }
                    Text { text: "\u255A"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 6 }
                    Text { text: "\u255D"; font.family: pixelFont.name; font.pixelSize: 18; color: surf.warnColor; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 6 }

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
                                        Keys.onReturnPressed: doFinalLogin()
                                        Keys.onEnterPressed: doFinalLogin()
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
                                        onClicked: { playClick(); doFinalLogin() } }
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
                if (surf.passwordCheckRunning) return
                if (defensePassword.text.length === 0) return
                surf.passwordCheckRunning = true
                defenseStatus.text = ">_VERIFYING FIXER CREDENTIALS._"; defenseStatus.color = surf.cyan
                playCheck()
                beginAuth(true)
            }
            function applyFinalResult(ok) {
                surf.passwordCheckRunning = false
                if (ok) {
                    defenseStatus.text = ">_AUTHORIZATION GRANTED. Welcome, Fixer._"; defenseStatus.color = surf.successColor
                    playSuccess(); fadeMusic()
                    successFade.start(); finalUnlock.start()
                } else {
                    defensePassword.text = ""
                    defenseStatus.text = ">_AUTHORIZATION DENIED._"; defenseStatus.color = surf.warnColor
                    playFail()
                    answerLine.visible = true; surf.answerIdx = 0; answerLine.text = ""
                    answerTypeTimer.start()
                }
            }

            // typewriter for the answer line, then SAFE reset (no poweroff)
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
                    // wrong FIXER password -> POWER OFF (Project Moon "Fixer" behavior)
                    defenseModal.opacity = 0.0
                    fadeMusic()
                    Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
            Timer { id: modalCloseTimer; interval: 450; repeat: false; onTriggered: {
                defenseModal.visible = false
                surf.failCount = 0
                surf.passwordCheckRunning = false
                passwordInput.text = ""; statusMessage.text = ""
                scrambleDisplay.text = ""
                bgMusic.play()
                passwordInput.forceActiveFocus()
            } }

            Component.onCompleted: {
                var v = volSettings.volume
                volTrack.volValue = v; bgAudioOut.volume = v
                clickSound.volume = v; successSound.volume = v; failSound.volume = v; checkSound.volume = v
                // once-per-boot intro gate: launcher exports INDEX_INTRO=1 first boot, 0 after.
                // (XHR local-file read is blocked by quickshell, so we use the env var instead.)
                var play = true
                try {
                    var flag = Quickshell.env("INDEX_INTRO")
                    if (flag !== undefined && flag !== null && String(flag) !== "")
                        play = (String(flag) === "1")
                } catch (e) { play = true }   // env API missing -> just play
                if (play) startIntro()
                else { surf.introActive = false; introLayer.opacity = 0.0; bgMusic.play(); passwordInput.forceActiveFocus() }
            }
        }
    }
}
