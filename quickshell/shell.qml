//@ pragma UseQApplication
// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  quickshell entry
//  Started under KWin (plasmashell is disabled).
//  Brings up wallpaper, top bar, atmosphere, notifications.
//  Wallpaper + atmosphere go on every screen; the bar, Prescript
//  and popups stay on the main screen (like Windows' default).
//  lock/lock.qml is NOT launched here: KWin has no
//  ext-session-lock; KDE's kscreenlocker handles locking.
// ============================================================

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    Bar {}
    Variants {
        model: Quickshell.screens
        Atmosphere {}
    }
    Notifications {}
    LazyLoader { active: Features.enabled("quicksettings"); component: QuickSettings {} }
    Osd {}
    LazyLoader { active: Features.enabled("prescript"); component: Prescript {} }
    DeviceWatch {}
    IntroSettings {}
    LazyLoader { active: Features.enabled("shortcuts"); component: Shortcuts {} }
    LazyLoader { active: Features.enabled("clipboard"); component: Clipboard {} }
}
