pragma Singleton
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  shared popup state
//  One place for "is this panel open", so the bar buttons,
//  keyboard shortcuts (KWin.shortcut) and the panels agree.
// ============================================================

import QtQuick
import Quickshell

Singleton {
    property bool quickSettingsOpen: false   // QuickSettings.qml  (Win+A, bar button)
    property bool clipboardOpen: false       // Clipboard.qml      (Win+V)
    property bool settingsOpen: false
    property bool introSettingsOpen: false
    property bool doNotDisturb: false        // Notifications.qml hides popups while true

    function toggleQuickSettings() { quickSettingsOpen = !quickSettingsOpen; if (quickSettingsOpen) clipboardOpen = false }
    function toggleClipboard()     { clipboardOpen = !clipboardOpen; if (clipboardOpen) quickSettingsOpen = false }
    function openSettings() { quickSettingsOpen = false; clipboardOpen = false; settingsOpen = true }
    function openIntroSettings() { settingsOpen = false; quickSettingsOpen = false; introSettingsOpen = true }
}
