// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  atmosphere (quickshell)
//  Full-screen BOTTOM layer (above Wallpaper): drifting cyan motes + a
//  subtitle ticker, drawn over the wallpaper, behind windows.
//  This replicates the HTML preview's living atmosphere.
//  Reuse tiny scene-graph textures; never repaint a screen-sized Canvas.
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: atmo
    // set per screen by the Variants in shell.qml
    property var modelData: null
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    // decoration only: an empty input region lets clicks through to the
    // Prescript card, which shares this layer
    mask: Region {}
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property bool animate: visible && (KWin.showingDesktop || !screen || KWin.obscuredOutputs.indexOf(screen.name) < 0)

    // ---- corner HUD (matches the preview corners) ----
    Text {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 14
        text: "// THE INDEX \u00b7 district: unregistered"
        font.family: atmo.pixel; font.pixelSize: 13; color: "#3A7CA5"
    }
    Text {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
        text: "… I hear the waves."
        font.family: atmo.pixel; font.pixelSize: 13; color: "#FF6B6B"
    }
    Text {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 14
        text: "> standby_"
        font.family: atmo.pixel; font.pixelSize: 13; color: "#3A7CA5"
    }

    // ---- drifting cyan motes ----
    Item {
        id: particles
        anchors.fill: parent
        property real elapsed: 0
        Repeater {
            id: motes
            model: 60
            Image {
                property real px: Math.random() * particles.width
                property real py: Math.random() * particles.height
                readonly property real rise: (Math.random() * 0.4 + 0.12) / 0.033
                readonly property real drift: (Math.random() * 0.6 - 0.3) * 0.3 / 0.033
                readonly property real radius: Math.random() * 1.6 + 0.4
                x: px - width / 2; y: py - height / 2
                width: radius * 8; height: width
                source: Qt.resolvedUrl("assets/mote.svg")
                sourceSize.width: 32; sourceSize.height: 32
                opacity: Math.random() * 0.5 + 0.18
                function advance(seconds) {
                    py -= rise * seconds
                    px += drift * seconds
                    if (py < -5) { px = Math.random() * particles.width; py = particles.height + 5 }
                }
            }
        }
        Timer {
            interval: 50; running: atmo.animate; repeat: true
            property double previous: Date.now()
            onRunningChanged: previous = Date.now()
            onTriggered: {
                const now = Date.now()
                const seconds = Math.min((now - previous) / 1000, 0.1)
                previous = now
                particles.elapsed += seconds
                for (let i = 0; i < motes.count; ++i) {
                    const mote = motes.itemAt(i)
                    if (mote) mote.advance(seconds)
                }
            }
        }
    }

    // ---- breathing glow ----
    Rectangle {
        anchors.centerIn: parent
        width: 640; height: 640; radius: 320
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a5DADE2" }
            GradientStop { position: 1.0; color: "transparent" }
        }
        // Share the mote clock instead of driving a full-screen surface at 60 Hz.
        opacity: 0.7 - 0.3 * Math.cos(particles.elapsed * Math.PI * 2 / 5)
    }

    // ---- subtitle ticker ----
    Column {
        id: ticker
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        spacing: 3

        property var lines: [
            "The City remembers every name it is given.",
            "By the geometry of inevitability, the prey gathers here.",
            "Speak your name, and the door will know you.",
            "The Index keeps what the City forgets."
        ]
        property int idx: 0

        Text {
            id: subMain
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Perfect DOS VGA 437 Universal"; font.pixelSize: 21
            color: "#e8f4fa"
            opacity: 0
            style: Text.Raised; styleColor: "#0a5DADE2"
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "// THE INDEX"
            font.family: "Perfect DOS VGA 437 Universal"; font.pixelSize: 14
            color: "#3A7CA5"
            opacity: subMain.opacity
        }

        Timer {
            interval: 6500; running: atmo.animate; repeat: true; triggeredOnStart: true
            onTriggered: { subMain.opacity = 0; swap.restart(); }
        }
        Timer {
            id: swap; interval: 650
            onTriggered: {
                subMain.text = ticker.lines[ticker.idx];
                subMain.opacity = 1;
                ticker.idx = (ticker.idx + 1) % ticker.lines.length;
            }
        }
    }
}
