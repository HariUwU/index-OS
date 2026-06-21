// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  atmosphere (quickshell)
//  Full-screen BACKGROUND layer: drifting cyan motes + a
//  subtitle ticker, drawn over the wallpaper, behind windows.
//  This replicates the HTML preview's living atmosphere.
//  NOTE: a full-screen surface — needs real GPU (won't render
//  under VirtualBox, same GBM limit as the wallpaper).
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: atmo
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "index-atmosphere"

    // ---- drifting cyan motes ----
    Canvas {
        id: cv
        anchors.fill: parent
        property var parts: []
        Component.onCompleted: {
            for (var i = 0; i < 60; i++)
                parts.push({
                    x: Math.random() * width,
                    y: Math.random() * height,
                    r: Math.random() * 1.6 + 0.4,
                    s: Math.random() * 0.4 + 0.12,
                    a: Math.random() * 0.5 + 0.18,
                    d: Math.random() * 0.6 - 0.3
                });
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.shadowBlur = 6;
            ctx.shadowColor = "rgba(93,173,226,0.85)";
            for (var i = 0; i < parts.length; i++) {
                var p = parts[i];
                p.y -= p.s;
                p.x += p.d * 0.3;
                if (p.y < -5) { p.x = Math.random() * width; p.y = height + 5; }
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r, 0, 6.283);
                ctx.fillStyle = "rgba(93,173,226," + p.a + ")";
                ctx.fill();
            }
        }
        Timer { interval: 33; running: true; repeat: true; onTriggered: cv.requestPaint() }
    }

    // ---- breathing glow ----
    Rectangle {
        anchors.centerIn: parent
        width: 640; height: 640; radius: 320
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a5DADE2" }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.4; duration: 2500; easing.type: Easing.InOutSine }
        }
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
            font.family: "Perfect DOS VGA 437"; font.pixelSize: 21
            color: "#e8f4fa"
            opacity: 0
            style: Text.Raised; styleColor: "#0a5DADE2"
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "// THE INDEX"
            font.family: "Perfect DOS VGA 437"; font.pixelSize: 14
            color: "#3A7CA5"
            opacity: subMain.opacity
        }

        Timer {
            interval: 6500; running: true; repeat: true; triggeredOnStart: true
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
