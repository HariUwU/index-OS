// WILL OF THE CITY :: THE INDEX  —  calendar + media popup (click the clock)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: cal
    property bool open: false
    visible: open
    // centred under the clock, which sits in the middle of the bar
    anchors { top: true; left: true; right: true }
    margins { top: 32 }
    implicitHeight: 400
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "index-calendar"

    readonly property string pixel: "Perfect DOS VGA 437 Universal"
    readonly property color cyan:  "#5DADE2"
    readonly property color cyanB: "#85C5E8"
    readonly property color cyanD: "#3A7CA5"

    property var shown: new Date()
    property string mediaTitle: ""
    property string mediaStatus: ""

    function sh(c) { Quickshell.execDetached(["sh","-c",c]) }
    function monthName(d) {
        return ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE","JULY",
                "AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"][d.getMonth()]
    }

    Process {
        id: mediaProc
        command: ["sh","-c","playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null; echo '|'; playerctl status 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var p = text.split("|")
            cal.mediaTitle  = (p[0] || "").trim()
            cal.mediaStatus = (p[1] || "").trim()
        } }
    }
    Timer { interval: 3000; running: cal.open; repeat: true; triggeredOnStart: true
        onTriggered: mediaProc.running = true }

    Rectangle {
        // fixed-width card, centred horizontally under the clock
        width: 300
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: "#0a0e16"
        border.color: cal.cyan
        border.width: 2
        opacity: cal.open ? 1 : 0
        transform: Translate { y: cal.open ? 0 : -16
            Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ---- month header ----
            RowLayout {
                Layout.fillWidth: true
                Text { text: "<"; font.family: cal.pixel; font.pixelSize: 18; color: cal.cyanD
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                        onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth()-1, 1) } }
                Item { Layout.fillWidth: true }
                Text {
                    text: cal.monthName(cal.shown) + " " + cal.shown.getFullYear()
                    font.family: cal.pixel; font.pixelSize: 15; color: cal.cyanB
                }
                Item { Layout.fillWidth: true }
                Text { text: ">"; font.family: cal.pixel; font.pixelSize: 18; color: cal.cyanD
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                        onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth()+1, 1) } }
            }

            // ---- weekday row ----
            GridLayout {
                Layout.fillWidth: true
                columns: 7; columnSpacing: 0; rowSpacing: 2
                Repeater {
                    model: ["S","M","T","W","T","F","S"]
                    delegate: Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.family: cal.pixel; font.pixelSize: 12; color: cal.cyanD
                    }
                }
            }

            // ---- days ----
            GridLayout {
                Layout.fillWidth: true
                columns: 7; columnSpacing: 0; rowSpacing: 2
                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 26
                        readonly property int firstDow: new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 1).getDay()
                        readonly property int dim: new Date(cal.shown.getFullYear(), cal.shown.getMonth()+1, 0).getDate()
                        readonly property int dayNum: index - firstDow + 1
                        readonly property bool valid: dayNum >= 1 && dayNum <= dim
                        readonly property bool isToday: {
                            var n = new Date()
                            return valid && dayNum === n.getDate()
                                && cal.shown.getMonth() === n.getMonth()
                                && cal.shown.getFullYear() === n.getFullYear()
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 22
                            color: parent.isToday ? cal.cyan : "transparent"
                            visible: parent.valid
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.dayNum
                                font.family: cal.pixel; font.pixelSize: 13
                                color: parent.parent.isToday ? "#04141c" : cal.cyanB
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: cal.cyanD }

            // ---- media controls ----
            ColumnLayout {
                Layout.fillWidth: true; spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: cal.mediaTitle !== "" ? cal.mediaTitle : "nothing playing"
                    font.family: cal.pixel; font.pixelSize: 12
                    color: cal.mediaTitle !== "" ? cal.cyanB : cal.cyanD
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [
                            { label: "|<", cmd: "playerctl previous" },
                            { label: cal.mediaStatus === "Playing" ? "||" : "|>", cmd: "playerctl play-pause" },
                            { label: ">|", cmd: "playerctl next" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 30
                            color: mMa.containsMouse ? "#143245" : "#0c1620"
                            border.color: cal.cyanD; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.label
                                font.family: cal.pixel; font.pixelSize: 14; color: cal.cyanB }
                            MouseArea {
                                id: mMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { cal.sh(modelData.cmd); mediaProc.running = true }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
