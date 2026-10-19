// SPDX-License-Identifier: GPL-3.0-or-later
// The authenticator context belongs to kscreenlocker_greet, never to this theme.
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtMultimedia
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components as Workspace

Rectangle {
    id: root
    color: "#000000"
    implicitWidth: 1100
    implicitHeight: 700

    // These names form the native kscreenlocker_greet root-object contract.
    property bool locked: true
    property bool viewVisible: false
    property bool suspendToRamSupported: false
    property bool suspendToDiskSupported: false
    signal suspendToRam()
    signal suspendToDisk()

    readonly property color cyan: "#5DADE2"
    readonly property color cyanBright: "#85C5E8"
    readonly property color cyanDim: "#3A7CA5"
    readonly property color warning: "#FF6B6B"
    readonly property color success: "#5DE285"
    readonly property bool activeSurface: Window.window ? Window.window.active : false
    // A pending prompt is ready for input even during backend state changes.
    readonly property bool inputBlocked: phase !== "idle" || (!promptReady && authenticator.busy) || authenticator.inPasswordDelay
    readonly property bool audioSurface: activeSurface && !introActive

    property string phase: "idle"
    property string status: ""
    property string resultText: ""
    property string clockText: ""
    property string pamPrompt: ""
    property string pamMessage: ""
    property bool secretPrompt: true
    property bool promptReady: false
    property bool submitted: false
    property bool introActive: introConfig.enabled && introConfig.videoSource.toString() !== ""
    property bool completed: false
    property bool pendingSuccess: false
    property bool pendingFailure: false
    property int failCount: 0
    property double retryNotBefore: 0
    property real volume: 0.3

    IntroConfig { id: introConfig }
    FontLoader { id: pixelFont; source: Qt.resolvedUrl("assets/PerfectDOSVGA437-Universal.ttf") }
    KeyboardIndicator.KeyState { id: capsLock; key: Qt.Key_CapsLock }

    function focusPassword() {
        // Focus the input within each view; the native greeter chooses which
        // window receives keyboard events. Do not request window activation.
        if (introActive || phase !== "idle") return;
        if (defense.visible) defensePassword.forceActiveFocus();
        else password.forceActiveFocus();
    }
    function updateClock() {
        const now = new Date();
        const hour = now.getHours();
        clockText = "_" + String(hour % 12 || 12).padStart(2, "0") + ":"
            + String(now.getMinutes()).padStart(2, "0") + (hour >= 12 ? " PM._" : " AM._");
    }
    function finishIntro() {
        if (!introActive) return;
        introActive = false;
        introTimeout.stop();
        introWatchdog.stop();
        introVideo.stop();
        Qt.callLater(focusPassword);
    }
    function play(effect) {
        // Each screen has a root; only the focused screen emits audio.
        if (activeSurface && volume > 0 && effect.source && effect.status === SoundEffect.Ready) effect.play();
    }
    function updateMusic() {
        if (audioSurface && !defense.visible && phase !== "granted" && music.source && music.source.toString() !== "") music.play();
        else music.pause();
    }
    function ensureAuthentication() {
        if (completed && locked && activeSurface && !authenticator.unlocked &&
            !promptReady && phase === "idle" && !authenticator.inPasswordDelay)
            authenticator.startAuthenticating();
    }
    function submit() {
        if (inputBlocked || introActive || (defense.visible && !defense.inputVisible)) return;
        if (authenticator.unlocked) {
            showSuccess();
            return;
        }
        if (!promptReady) {
            ensureAuthentication();
            status = ">_WAITING_FOR_AUTHENTICATION._";
            focusPassword();
            return;
        }
        submitted = true;
        pendingFailure = false;
        pendingSuccess = false;
        phase = "checking";
        status = ">_CHECKING._";
        resultText = "";
        play(checkSound);
        checkingMinimum.restart();
        verifyTimer.restart();
        // Send once to KDE's existing PAM conversation. No passwords or success
        // decisions are held in another process or compared by the theme.
        const response = PasswordSync.password;
        promptReady = false;
        authenticator.respond(response);
        PasswordSync.password = "";
    }
    function showSuccess() {
        resetTimer.stop();
        defenseTimer.stop();
        defenseAnswerTimer.stop();
        verifyTimer.stop();
        phase = "granted";
        resultText = "_ACCESS_GRANTED._";
        status = defense.visible ? ">_AUTHORIZATION GRANTED. Welcome, Fixer._" : ">_LOGIN_SUCCESS._";
        PasswordSync.password = "";
        play(successSound);
        music.stop();
        unlockTimer.restart();
    }
    function showFailure() {
        verifyTimer.stop();
        phase = "denied";
        resultText = "_ACCESS_DENIED._";
        status = defense.visible ? ">_AUTHORIZATION_DENIED._" : ">_WRONG_PASSWORD._";
        PasswordSync.password = "";
        play(failSound);
        if (defense.visible) {
            defense.answerIndex = 0;
            defenseAnswerTimer.restart();
        }
        resetTimer.interval = Math.max(1500, retryNotBefore - Date.now());
        resetTimer.restart();
        if (failCount >= 3 && !defense.visible) defenseTimer.restart();
    }
    function resolveResult() {
        if (checkingMinimum.running) return;
        if (pendingSuccess) showSuccess();
        else if (pendingFailure) showFailure();
    }
    function resetPrompt() {
        if (authenticator.unlocked) return;
        phase = "idle";
        resultText = "";
        status = "";
        submitted = false;
        pendingFailure = false;
        PasswordSync.password = "";
        // KDE's aggregate authenticator returns to Idle after a failed attempt.
        // Respect its PAM delay before starting another conversation.
        ensureAuthentication();
        Qt.callLater(focusPassword);
    }

    Connections {
        target: authenticator
        function onPromptForSecretChanged() {
            root.promptReady = authenticator.promptForSecret !== "";
            if (!root.promptReady) return;
            root.secretPrompt = true;
            root.pamPrompt = authenticator.promptForSecret;
            root.promptReady = true;
            // Additional PAM prompts (for example OTP) need another response.
            if (root.phase === "checking") {
                checkingMinimum.stop();
                verifyTimer.stop();
                root.phase = "idle";
                root.status = "";
            }
            Qt.callLater(root.focusPassword);
        }
        function onPromptChanged() {
            root.promptReady = authenticator.prompt !== "";
            if (!root.promptReady) return;
            root.secretPrompt = false;
            root.pamPrompt = authenticator.prompt;
            root.promptReady = true;
            checkingMinimum.stop();
            verifyTimer.stop();
            root.phase = "idle";
            root.status = "";
            Qt.callLater(root.focusPassword);
        }
        function onInfoMessageChanged() { root.pamMessage = authenticator.infoMessage; }
        function onErrorMessageChanged() { root.pamMessage = authenticator.errorMessage; }
        function onFailed(kind) {
            if (kind !== ScreenLocker.Authenticator.None) return;
            root.failCount += 1;
            root.promptReady = false;
            root.pendingFailure = true;
            root.pendingSuccess = false;
            root.resolveResult();
        }
        function onLoginFailedDelayStarted(kind, source, microseconds) {
            if (kind !== ScreenLocker.Authenticator.None) return;
            root.retryNotBefore = Date.now() + Math.ceil(microseconds / 1000) + 100;
        }
        function onSucceeded() {
            // This signal also covers native fingerprint / smartcard success.
            authenticator.stopAuthenticating();
            root.pendingSuccess = true;
            root.pendingFailure = false;
            root.finishIntro();
            root.resolveResult();
        }
    }

    onActiveSurfaceChanged: if (completed) Qt.callLater(focusPassword)
    onAudioSurfaceChanged: if (completed) updateMusic()
    onPhaseChanged: if (completed) updateMusic()
    onViewVisibleChanged: if (viewVisible && completed) Qt.callLater(focusPassword)
    onLockedChanged: ensureAuthentication()

    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.updateClock() }
    // Like Breeze, keep PAM alive and retry when its worker was not ready at
    // component creation. Only the active view owns the heartbeat.
    Timer {
        interval: 1000; repeat: true
        running: root.completed && root.locked && root.activeSurface && !authenticator.unlocked
            && !root.promptReady && root.phase === "idle" && !authenticator.inPasswordDelay
        onTriggered: root.ensureAuthentication()
    }
    Timer { id: checkingMinimum; interval: 1200; onTriggered: root.resolveResult() }
    Timer { id: verifyTimer; interval: 600; onTriggered: root.status = ">_VERIFYING._" }
    Timer { id: resetTimer; interval: 1500; onTriggered: root.resetPrompt() }
    Timer { id: defenseTimer; interval: 1800; onTriggered: defense.startSequence() }
    Timer {
        id: unlockTimer
        interval: 900
        onTriggered: {
            // The native greeter also independently checks isUnlocked() before
            // honoring Qt.quit(); animation cannot unlock an unauthenticated session.
            if (authenticator.unlocked) Qt.quit();
        }
    }

    MediaPlayer {
        id: music
        source: Qt.resolvedUrl("assets/sounds/bg.mp3")
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: root.volume }
        onErrorOccurred: { source = ""; }
    }
    SoundEffect { id: clickSound; source: Qt.resolvedUrl("assets/sounds/click.wav"); volume: root.volume }
    SoundEffect { id: checkSound; source: Qt.resolvedUrl("assets/sounds/check.wav"); volume: root.volume }
    SoundEffect { id: failSound; source: Qt.resolvedUrl("assets/sounds/fail.wav"); volume: root.volume }
    SoundEffect { id: successSound; source: Qt.resolvedUrl("assets/sounds/success.wav"); volume: root.volume }

    Item {
        id: terminal
        width: 1100
        height: 450
        anchors.centerIn: parent
        scale: Math.min(1.15, root.width * 0.82 / width, root.height * 0.76 / height)
        opacity: root.introActive ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 600 } }

        Text {
            x: 0; y: 20
            text: root.clockText
            color: root.cyanBright
            font.family: pixelFont.name; font.pixelSize: 56
            style: Text.Outline; styleColor: root.cyan
        }
        Text {
            x: 92; y: 140; width: 240; height: 240
            text: logoImage.status === Image.Ready ? "" : ">_INDEX"
            color: root.cyanBright
            font.family: pixelFont.name; font.pixelSize: 40
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            Image {
                id: logoImage
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/Logo.png")
                fillMode: Image.PreserveAspectFit
                smooth: false
                visible: status === Image.Ready
            }
        }
        Item {
            id: loginForm
            x: 500; y: 95; width: 600; height: 270

            Rectangle {
                width: 70; height: 70; color: "transparent"
                border.width: 2; border.color: root.cyan
                Image {
                    id: accountPhoto
                    anchors.fill: parent; anchors.margins: 2
                    // KDE account picture (System Settings > Users).
                    source: (typeof kscreenlocker_userImage !== "undefined" && kscreenlocker_userImage)
                            ? kscreenlocker_userImage : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: false
                    visible: status === Image.Ready
                }
                Kirigami.Icon {
                    anchors.fill: parent; anchors.margins: 10
                    source: "user-identity"
                    color: root.cyanBright
                    visible: accountPhoto.status !== Image.Ready
                }
            }
            Rectangle {
                x: 80; y: 5; width: 520; height: 60; color: "transparent"
                border.width: 2; border.color: root.cyan
                Text {
                    anchors.fill: parent; anchors.margins: 14
                    text: "_" + kscreenlocker_userName.toUpperCase() + "._"
                    color: root.cyanBright
                    font.family: pixelFont.name; font.pixelSize: 24
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                x: 80; y: 90; width: 520; height: 50; color: "transparent"
                border.width: 2
                border.color: root.phase === "idle" ? root.cyan : root.phase === "granted" ? root.success : root.warning
                TextInput {
                    id: password
                    anchors.fill: parent; anchors.margins: 12
                    text: PasswordSync.password
                    onTextEdited: PasswordSync.password = text
                    color: root.cyanBright
                    font.family: pixelFont.name; font.pixelSize: 22
                    echoMode: root.secretPrompt ? TextInput.Password : TextInput.Normal
                    passwordCharacter: "."
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: !root.inputBlocked && !root.introActive && !defense.visible
                    visible: root.phase === "idle"
                    focus: true
                    selectByMouse: true
                    clip: true
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    Accessible.name: root.pamPrompt || "Password"
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: PasswordSync.password = ""
                }
                Text {
                    anchors.fill: parent; anchors.margins: 12
                    visible: root.phase !== "idle"
                    text: root.phase === "checking" ? scramble.text : root.resultText
                    color: root.phase === "granted" ? root.success : root.warning
                    font.family: pixelFont.name; font.pixelSize: 22
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Text {
                x: 80; y: 151; width: 520
                text: root.status
                color: root.phase === "granted" ? root.success : root.phase === "denied" ? root.warning : root.cyan
                font.family: pixelFont.name; font.pixelSize: 18
                wrapMode: Text.Wrap
            }
            Controls.AbstractButton {
                id: loginButton
                x: 80; y: 195
                width: loginText.implicitWidth; height: 36
                enabled: !root.inputBlocked && !root.introActive && !defense.visible
                Accessible.name: "Unlock"
                onClicked: { root.play(clickSound); root.submit(); }
                background: Rectangle { color: "transparent"; border.width: loginButton.activeFocus ? 1 : 0; border.color: root.cyan }
                contentItem: Text {
                    id: loginText
                    text: "<_Login._>"
                    color: loginButton.hovered ? "#FFFFFF" : root.cyanBright
                    opacity: loginButton.enabled ? 1 : 0.4
                    font.family: pixelFont.name; font.pixelSize: 26
                }
            }
            Text {
                x: 80; y: 240; width: 520
                text: [capsLock.locked ? ">_CAPS_LOCK_ON._" : "", root.pamMessage,
                    root.promptReady && root.pamPrompt && root.pamPrompt.trim() !== "Password:" ? root.pamPrompt : ""].filter(Boolean).join("\n")
                color: root.cyanDim
                font.family: pixelFont.name; font.pixelSize: 16
                wrapMode: Text.Wrap
            }
        }
    }

    QtObject {
        id: scramble
        property string text: ""
        readonly property string chars: "!@#$%^&*()_+-=[]{}|;:,.<>?/~abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        function update() {
            let next = "_";
            for (let i = 0; i < 12; i++) next += chars.charAt(Math.floor(Math.random() * chars.length));
            text = next + "._";
        }
    }
    Timer {
        interval: 50; repeat: true; running: root.phase === "checking"; triggeredOnStart: true
        onTriggered: scramble.update()
    }

    Row {
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: 30; anchors.bottomMargin: 30
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "VOL"
            font.family: pixelFont.name; font.pixelSize: 14; color: root.cyanDim
        }
        Controls.Slider {
            id: volumeSlider
            width: 120; height: 24
            from: 0; to: 1; value: root.volume
            onMoved: root.volume = value
            Accessible.name: "Lock screen audio volume"
            background: Rectangle { x: 0; y: 11; width: 120; height: 2; color: root.cyanDim }
            handle: Rectangle {
                x: volumeSlider.visualPosition * (volumeSlider.width - width)
                y: 7; width: 10; height: 10; rotation: 45; color: root.cyan
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.volume * 100) + "%"
            font.family: pixelFont.name; font.pixelSize: 14; color: root.cyanDim
        }
    }
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.rightMargin: 30; anchors.bottomMargin: 30
        spacing: 20
        Workspace.KeyboardLayoutSwitcher {
            id: keyboardSwitcher
            visible: hasMultipleKeyboardLayouts
            width: layoutLabel.implicitWidth; height: 24
            acceptedButtons: Qt.LeftButton
            Text {
                id: layoutLabel
                text: keyboardSwitcher.layoutNames.shortName
                font.family: pixelFont.name; font.pixelSize: 16; color: root.cyanDim
            }
        }
        Text {
            text: ">_THE INDEX._"
            font.family: pixelFont.name; font.pixelSize: 16; color: root.cyanDim
        }
    }

    // Same theatrical third-failure screen, while the account's native PAM
    // authenticator remains the only authority. Failure never powers off a PC.
    Rectangle {
        id: defense
        anchors.fill: parent
        color: "#000000"
        visible: false
        z: 10
        property int typeIndex: 0
        property bool inputVisible: false
        property int answerIndex: 0
        onVisibleChanged: if (root.completed) root.updateMusic()
        readonly property string answerText: "◆ The City's will is absolute. There is no negotiation."
        readonly property var warningSegments: [
            { text: "The ", color: "#FFFFFF" },
            { text: "Head", color: "#FFD700" },
            { text: " has issued a decree.\nUnauthorized access detected in ", color: "#FFFFFF" },
            { text: "the City", color: "#FFA500" },
            { text: ".\n\nBy the Will of the City,\nthis terminal will alert the nearby\n", color: "#FFFFFF" },
            { text: "Index Proxy", color: "#F3F1EB" },
            { text: " and ", color: "#FFFFFF" },
            { text: "[REDACTED]", color: "#FF3333" },
            { text: ".", color: "#FFFFFF" }
        ]
        readonly property int warningLength: warningSegments.reduce((length, segment) => length + segment.text.length, 0)

        function warningHtml() {
            let left = typeIndex;
            let result = "";
            for (let i = 0; i < warningSegments.length && left > 0; i++) {
                const segment = warningSegments[i];
                result += "<font color='" + segment.color + "'>"
                    + segment.text.substring(0, left).replace(/\n/g, "<br>") + "</font>";
                left -= segment.text.length;
            }
            return result;
        }

        function startSequence() {
            visible = true;
            typeIndex = 0;
            answerIndex = 0;
            inputVisible = false;
            PasswordSync.password = "";
            typewriter.restart();
        }
        Rectangle {
            anchors.centerIn: parent
            width: 820; height: 520
            scale: Math.min(1, root.width * 0.9 / width, root.height * 0.88 / height)
            color: "#000000"; border.width: 2; border.color: root.warning
            Repeater {
                model: ["╔", "╗", "╚", "╝"]
                Text {
                    required property int index
                    required property string modelData
                    x: index % 2 === 0 ? 6 : parent.width - width - 6
                    y: index < 2 ? 6 : parent.height - height - 6
                    text: modelData
                    font.family: pixelFont.name; font.pixelSize: 18; color: root.warning
                }
            }
            Text {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 36
                text: ">_ WILL OF THE CITY _<"
                font.family: pixelFont.name; font.pixelSize: 20; color: root.warning
                SequentialAnimation on opacity {
                    running: defense.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 600 }
                    NumberAnimation { from: 0.3; to: 1; duration: 600 }
                }
            }
            Rectangle { x: 40; y: 82; width: parent.width - 80; height: 1; color: root.warning; opacity: 0.5 }
            Text {
                x: 40; y: 102; width: parent.width - 80
                text: defense.warningHtml()
                font.family: pixelFont.name; font.pixelSize: 22
                color: "#FFFFFF"; wrapMode: Text.WordWrap; lineHeight: 1.4; textFormat: Text.RichText
            }
            Text {
                x: 40; y: 300; width: parent.width - 80
                text: defense.answerText.substring(0, defense.answerIndex)
                font.family: pixelFont.name; font.pixelSize: 18; color: "#FFD700"
                wrapMode: Text.WordWrap
            }
            Item {
                x: 40; y: 355; width: parent.width - 80; height: 130
                visible: defense.inputVisible
                Text {
                    text: ">_ FIXER AUTHORIZATION REQUIRED:_"
                    font.family: pixelFont.name; font.pixelSize: 18; color: root.warning
                }
                Rectangle {
                    y: 35; width: 490; height: 46; color: "transparent"
                    border.width: 2; border.color: root.phase === "idle" ? root.cyan : root.warning
                    TextInput {
                        id: defensePassword
                        anchors.fill: parent; anchors.margins: 10
                        text: PasswordSync.password
                        onTextEdited: PasswordSync.password = text
                        font.family: pixelFont.name; font.pixelSize: 20; color: root.cyanBright
                        echoMode: root.secretPrompt ? TextInput.Password : TextInput.Normal
                        passwordCharacter: "."
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: !root.inputBlocked
                        clip: true
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        Accessible.name: root.pamPrompt || "Password"
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: PasswordSync.password = ""
                    }
                }
                Controls.AbstractButton {
                    id: authorize
                    x: 510; y: 35; width: 220; height: 46
                    enabled: !root.inputBlocked
                    Accessible.name: "Unlock"
                    onClicked: { root.play(clickSound); root.submit(); }
                    background: Rectangle { color: "transparent"; border.width: authorize.activeFocus ? 1 : 0; border.color: root.cyan }
                    contentItem: Text {
                        text: "<_AUTHORIZE._>"
                        font.family: pixelFont.name; font.pixelSize: 20
                        color: authorize.hovered ? "#FFFFFF" : root.warning
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    y: 94; width: parent.width
                    text: root.status
                    font.family: pixelFont.name; font.pixelSize: 17
                    color: root.phase === "granted" ? root.success : root.warning
                    wrapMode: Text.Wrap
                }
            }
        }
        Timer {
            id: typewriter
            interval: 38; repeat: true
            onTriggered: {
                if (defense.typeIndex < defense.warningLength) defense.typeIndex++;
                else {
                    stop();
                    defense.inputVisible = true;
                    Qt.callLater(root.focusPassword);
                }
            }
        }
        Timer {
            id: defenseAnswerTimer
            interval: 45; repeat: true
            onTriggered: {
                if (defense.answerIndex < defense.answerText.length) defense.answerIndex++;
                else stop();
            }
        }
    }

    // Keep the original black CRT treatment instead of Plasma's blurred wallpaper.
    Item {
        anchors.fill: parent; z: 20; opacity: 0.15
        Repeater {
            model: Math.floor(root.height / 4)
            Rectangle { required property int index; width: root.width; height: 2; y: index * 4 + 2; color: "#000000" }
        }
    }
    Rectangle {
        anchors.fill: parent; z: 21
        gradient: Gradient {
            GradientStop { position: 0; color: "#80000000" }
            GradientStop { position: 0.5; color: "#00000000" }
            GradientStop { position: 1; color: "#80000000" }
        }
    }
    Rectangle {
        anchors.fill: parent; color: "#000000"; z: 22
        opacity: root.phase === "granted" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 850 } }
    }

    Rectangle {
        id: intro
        anchors.fill: parent; color: "#000000"; z: 30
        visible: opacity > 0
        opacity: root.introActive ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }
        MediaPlayer {
            id: introVideo
            source: root.introActive ? introConfig.videoSource : ""
            videoOutput: video
            audioOutput: AudioOutput { volume: root.activeSurface && root.introActive ? root.volume : 0 }
            onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia || mediaStatus === MediaPlayer.InvalidMedia) Qt.callLater(root.finishIntro)
            onErrorOccurred: Qt.callLater(root.finishIntro)
            onPlaybackStateChanged: {
                if (playbackState === MediaPlayer.PausedState) introWatchdog.resetProgress();
            }
        }
        VideoOutput { id: video; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
        MouseArea { anchors.fill: parent; onDoubleClicked: skipIntro.visible = true }
        Controls.AbstractButton {
            id: skipIntro
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 26
            width: 160; height: 38
            // A visible skip affordance keeps authentication immediately available.
            visible: true
            Accessible.name: "Skip intro"
            onClicked: root.finishIntro()
            background: Rectangle { color: skipIntro.hovered ? "#143245" : "#0A0E16"; border.width: 2; border.color: root.cyan }
            contentItem: Text {
                text: ">_ SKIP _<"
                font.family: pixelFont.name; font.pixelSize: 18; color: root.cyanBright
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
        }
        Timer { id: introTimeout; interval: 60000; onTriggered: root.finishIntro() }
        Timer {
            id: introWatchdog; interval: 500; repeat: true
            property int lastPosition: 0
            property int idleMs: 0
            property bool hasProgress: false
            function resetProgress() {
                introWatchdog.lastPosition = introVideo.position;
                introWatchdog.idleMs = 0;
            }
            function checkProgress() {
                if (!root.introActive) return;
                if (introVideo.playbackState === MediaPlayer.PausedState) {
                    introWatchdog.resetProgress();
                    return;
                }
                if (introVideo.playbackState === MediaPlayer.PlayingState &&
                    introVideo.position > introWatchdog.lastPosition) {
                    introWatchdog.hasProgress = true;
                    introWatchdog.idleMs = 0;
                } else {
                    introWatchdog.idleMs += introWatchdog.interval;
                }
                introWatchdog.lastPosition = introVideo.position;
                if (introWatchdog.idleMs >= (introWatchdog.hasProgress ? 6000 : 2000))
                    root.finishIntro();
            }
            onTriggered: introWatchdog.checkProgress()
        }
    }

    Component.onCompleted: {
        root.completed = true;
        root.updateClock();
        if (typeof config !== "undefined") {
            if (config.indexVolume !== undefined) root.volume = Math.max(0, Math.min(1, config.indexVolume));
            if (config.indexIntro !== undefined && !config.indexIntro) root.introActive = false;
        }
        // KDE retains prompt text after a failed conversation. A new output
        // may adopt it only while native authentication is still active.
        const conversationActive = authenticator.state === ScreenLocker.Authenticators.Authenticating;
        if (conversationActive && authenticator.promptForSecret) {
            root.pamPrompt = authenticator.promptForSecret;
            root.secretPrompt = true;
            root.promptReady = true;
        } else if (conversationActive && authenticator.prompt) {
            root.pamPrompt = authenticator.prompt;
            root.secretPrompt = false;
            root.promptReady = true;
        }
        root.ensureAuthentication();
        if (root.introActive) {
            if (introVideo.mediaStatus === MediaPlayer.InvalidMedia || introVideo.error !== MediaPlayer.NoError) root.finishIntro();
            else { introVideo.play(); introTimeout.start(); introWatchdog.start(); }
        }
        else { root.updateMusic(); Qt.callLater(root.focusPassword); }
    }
}
