// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  wallpaper (quickshell)
//  Full-screen BACKGROUND layer. Draws the desktop background now that
//  plasmashell is off. Atmosphere sits on WlrLayer.Bottom, so
//  it always renders above this surface.
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wall
    // set per screen by the Variants in shell.qml
    property var modelData: null
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}          // never takes clicks
    exclusionMode: ExclusionMode.Ignore
    color: "#000000"
    WlrLayershell.layer: WlrLayer.Background
    // KWin derives the window type from this protocol namespace.
    WlrLayershell.namespace: "desktop"

    // A native black background remains when the optional wallpaper is absent.
    Rectangle { anchors.fill: parent; color: "#000000" }
    Image {
        anchors.fill: parent
        source: Quickshell.shellDir + "/assets/wall.png"
        visible: status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
}
