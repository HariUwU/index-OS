// WILL OF THE CITY :: THE INDEX  —  CLASH minigame (ORIGINAL)
// Original turn-based "clash" parody — NOT a copy of any commercial game's
// art or systems. Sprites are LOCAL drop-ins (assets/boss/*, gitignored):
//   assets/boss/boss.png      (the enemy)   — optional, falls back to emblem
//   assets/boss/player.png    (you)         — optional, falls back to emblem
// Emits gameWon() when the boss is defeated -> the lock unlocks.
import QtQuick
import QtQuick.Layouts

Item {
    id: game
    anchors.fill: parent
    signal gameWon()
    signal gameQuit()

    property string pixel: "Perfect DOS VGA 437"
    property color cyan:  "#5DADE2"
    property color cyanB: "#85C5E8"
    property color cyanD: "#3A7CA5"
    property color warn:  "#FF6B6B"
    property color good:  "#5DE285"

    // ---- state ----
    property int pHP: 100
    property int pMax: 100
    property int bHP: 160
    property int bMax: 160
    property bool busy: false
    property string log: "A clash bars the gate. Win to enter."

    function clamp(v,a,b){ return Math.max(a, Math.min(b, v)) }
    function roll(power){ return power + Math.floor(Math.random()*6) }   // power + d6

    // one clash round: skill power vs boss power
    function clash(skillName, skillPower, skillDmg) {
        if (busy) return
        busy = true
        var bossPower = 2 + Math.floor(Math.random()*5)         // boss 2..6
        var you = roll(skillPower)
        var them = roll(bossPower)
        coinYou.text = "[" + you + "]"; coinBoss.text = "[" + them + "]"
        if (you >= them) {
            var dmg = skillDmg + (you - them)
            game.bHP = clamp(game.bHP - dmg, 0, game.bMax)
            game.log = skillName + " WINS clash  (" + you + " vs " + them + ")  -" + dmg
        } else {
            var bd = 8 + (them - you) * 2
            game.pHP = clamp(game.pHP - bd, 0, game.pMax)
            game.log = skillName + " LOSES clash  (" + you + " vs " + them + ")  you -" + bd
        }
        resolveTimer.start()
    }
    Timer {
        id: resolveTimer; interval: 600; repeat: false
        onTriggered: {
            if (game.bHP <= 0) { game.log = "THE GATE OPENS."; winTimer.start() }
            else if (game.pHP <= 0) { game.log = "Defeated. The body resets."; loseTimer.start() }
            else game.busy = false
        }
    }
    Timer { id: winTimer; interval: 700; repeat: false; onTriggered: game.gameWon() }
    Timer { id: loseTimer; interval: 900; repeat: false; onTriggered: {
        game.pHP = game.pMax; game.bHP = Math.min(game.bMax, game.bHP + 40); game.busy = false } }

    // ===== UI =====
    Rectangle { anchors.fill: parent; color: "#04141c"; opacity: 0.97 }

    // boss
    Item {
        id: bossSlot
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220; height: 220
        Image {
            anchors.fill: parent; fillMode: Image.PreserveAspectFit
            source: Qt.resolvedUrl("assets/boss/boss.png")
            onStatusChanged: if (status === Image.Error) visible = false
        }
        // fallback emblem if no boss.png
        Image {
            anchors.fill: parent; fillMode: Image.PreserveAspectFit
            source: Qt.resolvedUrl("assets/Logo.png")
            visible: parent.children[0].status !== Image.Ready
            opacity: 0.85
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bossSlot.bottom; anchors.topMargin: 6
        text: "THE INDEX NURSEFATHER"
        font.family: game.pixel; font.pixelSize: 16; color: game.warn
    }
    // boss HP
    Rectangle {
        id: bBar; anchors.top: bossSlot.bottom; anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360; height: 16; color: "#0a0e16"; border.color: game.warn; border.width: 1
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 2; width: (parent.width-4) * game.bHP/game.bMax; color: game.warn
            Behavior on width { NumberAnimation { duration: 350 } } }
        Text { anchors.centerIn: parent; text: game.bHP + " / " + game.bMax
            font.family: game.pixel; font.pixelSize: 11; color: "#fff" }
    }

    // clash coins
    RowLayout {
        anchors.centerIn: parent
        spacing: 60
        Text { id: coinYou;  text: "[ ]"; font.family: game.pixel; font.pixelSize: 34; color: game.cyanB }
        Text { text: "VS"; font.family: game.pixel; font.pixelSize: 20; color: game.cyanD }
        Text { id: coinBoss; text: "[ ]"; font.family: game.pixel; font.pixelSize: 34; color: game.warn }
    }

    // log line
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: pBar.top; anchors.bottomMargin: 26
        text: game.log
        font.family: game.pixel; font.pixelSize: 14; color: game.cyanB
    }

    // player HP
    Rectangle {
        id: pBar; anchors.bottom: skills.top; anchors.bottomMargin: 22
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360; height: 16; color: "#0a0e16"; border.color: game.cyan; border.width: 1
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 2; width: (parent.width-4) * game.pHP/game.pMax; color: game.cyan
            Behavior on width { NumberAnimation { duration: 350 } } }
        Text { anchors.centerIn: parent; text: "YOU  " + game.pHP + " / " + game.pMax
            font.family: game.pixel; font.pixelSize: 11; color: "#04141c" }
    }

    // skills
    RowLayout {
        id: skills
        anchors.bottom: parent.bottom; anchors.bottomMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        Repeater {
            model: [
                { n: "SLASH",  p: 4, d: 14, c: game.cyan  },
                { n: "PIERCE", p: 3, d: 20, c: game.cyanB },
                { n: "GUARD",  p: 6, d: 8,  c: game.good  }
            ]
            delegate: Rectangle {
                required property var modelData
                width: 130; height: 52
                color: ma.containsMouse && !game.busy ? modelData.c : "#0a0e16"
                border.color: modelData.c; border.width: 2
                opacity: game.busy ? 0.4 : 1.0
                Column {
                    anchors.centerIn: parent; spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n
                        font.family: game.pixel; font.pixelSize: 16
                        color: ma.containsMouse && !game.busy ? "#04141c" : modelData.c }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: "pow " + modelData.p + "  dmg " + modelData.d
                        font.family: game.pixel; font.pixelSize: 10; color: game.cyanD }
                }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!game.busy) game.clash(modelData.n, modelData.p, modelData.d)
                }
            }
        }
    }

    // bail out to password
    Text {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 20
        text: ">_ use password _<"
        font.family: game.pixel; font.pixelSize: 13; color: game.cyanD
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: game.gameQuit() }
    }
}
