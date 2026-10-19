// ============================================================
//  WILL OF THE CITY :: THE INDEX  —  KWin side of the bridge
//  Loaded into KWin by index-kwin-bridge (org.kde.kwin.Scripting).
//  Pushes the taskbar state as one JSON string over D-Bus to
//  org.index.KWinBridge whenever a window or desktop changes.
// ============================================================

const SERVICE = "org.index.KWinBridge";

let seq = 0;
const order = {};          // internalId -> first-seen number (stable taskbar order)
const watched = {};
let lastCoverage = "[]";
// KWin's scripting API exposes window opacity, not the client's opaque region.
// Be conservative: leave effects running beneath terminals and unknown clients.
const OPAQUE_APPS = ["firefox", "org.kde.dolphin", "org.kde.kate", "org.kde.kwrite", "mpv", "chromium-bsu"];

function idOf(w) { return w.internalId.toString(); }

function listed(w) {
    if (w.skipTaskbar || w.specialWindow) return false;
    return w.normalWindow || (w.dialog && !w.transient);
}

function desktopOf(w) {
    if (w.onAllDesktops || !w.desktops.length) return 0;
    const want = w.desktops[0].id;
    const all = workspace.desktops;
    for (let i = 0; i < all.length; i++)
        if (all[i].id === want) return i + 1;
    return 0;
}

// INDEX's background has no visible pixels beneath a full-size opaque app.
// Keep each uncovered monitor animated, and resume when showing the desktop.
function coveredOutputs(goneId) {
    const covered = {};
    for (const w of workspace.windowList()) {
        if (!listed(w) || idOf(w) === goneId || w.minimized || w.opacity < 1 || !w.output) continue;
        const app = String(w.desktopFileName || w.resourceClass || "").toLowerCase();
        if (OPAQUE_APPS.indexOf(app) < 0) continue;
        const desktop = workspace.currentDesktopForScreen(w.output);
        if (!w.onAllDesktops && !w.desktops.some(d => d.id === desktop.id)) continue;
        if (w.activities.length && w.activities.indexOf(workspace.currentActivity) < 0) continue;
        const area = workspace.clientArea(KWin.MaximizeArea, w);
        const r = w.frameGeometry;
        if (r.x <= area.x && r.y <= area.y &&
            r.x + r.width >= area.x + area.width && r.y + r.height >= area.y + area.height)
            covered[w.output.name] = true;
    }
    return Object.keys(covered).sort();
}

function coverageChanged() {
    // Moving a small window must not stream frame-by-frame taskbar updates.
    if (JSON.stringify(coveredOutputs()) !== lastCoverage) push();
}

function push(goneId) {
    const all = workspace.desktops;
    let current = 1;
    for (let i = 0; i < all.length; i++)
        if (all[i].id === workspace.currentDesktop.id) current = i + 1;

    const wins = [];
    for (const w of workspace.windowList()) {
        if (!listed(w)) continue;
        const id = idOf(w);
        if (id === goneId) continue;
        if (!(id in order)) order[id] = ++seq;
        wins.push({
            id: id,
            title: w.caption,
            appId: w.desktopFileName || w.resourceClass || "",
            minimized: w.minimized,
            attention: w.demandsAttention,
            desktop: desktopOf(w),
            seq: order[id]
        });
    }
    wins.sort((a, b) => a.seq - b.seq);

    const active = workspace.activeWindow;
    const obscuredOutputs = coveredOutputs(goneId);
    lastCoverage = JSON.stringify(obscuredOutputs);
    callDBus(SERVICE, "/bridge", SERVICE, "Push", JSON.stringify({
        active: active && listed(active) ? idOf(active) : "",
        current: current,
        names: all.map(d => d.name),
        windows: wins,
        obscuredOutputs: obscuredOutputs
    }));
}

function watch(w) {
    const id = idOf(w);
    if (watched[id]) return;
    watched[id] = true;
    const changed = () => push();
    w.captionChanged.connect(changed);
    w.minimizedChanged.connect(changed);
    w.desktopsChanged.connect(changed);
    w.demandsAttentionChanged.connect(changed);
    w.skipTaskbarChanged.connect(changed);
    w.frameGeometryChanged.connect(coverageChanged);
    w.opacityChanged.connect(coverageChanged);
    w.activitiesChanged.connect(changed);
}

// Windows key alone opens the INDEX start menu. Plasma 6.7 handles a bare
// Meta tap as a normal global shortcut (install.sh frees it from plasmashell).
// Listed in System Settings > Shortcuts > KWin as "THE INDEX: Start menu".
registerShortcut("INDEX Start Menu", "THE INDEX: Start menu", "Meta",
                 () => callDBus(SERVICE, "/bridge", SERVICE, "ToggleStartMenu"));

// Windows-style shortcuts. Each one sends Shortcut(name) to the bridge and
// quickshell/Shortcuts.qml decides what to do. A key that something else
// already holds in kglobalaccel makes registerShortcut silently get no key,
// so install.sh frees (or checks) these keys before KWin loads this script.
// NOT registered here on purpose (KDE's own defaults already do the job,
// see the table in install.sh):
//   Meta+E  Dolphin            ([services][org.kde.dolphin.desktop] _launch)
//   Meta+I  System Settings    ([services][systemsettings.desktop] _launch)
//   Meta+D  show desktop       ([kwin] "Show Desktop")
//   Meta+Tab overview          ([kwin] "Overview", set by configure-shortcuts.py)
function indexShortcut(id, label, keys, name) {
    if (typeof INDEX_FEATURES !== "undefined") {
        if (!INDEX_FEATURES.shortcuts) return;
        if (name === "clipboard" && !INDEX_FEATURES.clipboard) return;
        if (name === "quicksettings" && !INDEX_FEATURES.quicksettings) return;
    }
    registerShortcut(id, "THE INDEX: " + label, keys,
                     () => callDBus(SERVICE, "/bridge", SERVICE, "Shortcut", name));
}
indexShortcut("INDEX Clipboard",      "Clipboard history",     "Meta+V",         "clipboard");
indexShortcut("INDEX Quick Settings", "Quick settings",        "Meta+A",         "quicksettings");
indexShortcut("INDEX Screenshot",     "Screenshot (region)",   "Meta+Shift+S",   "screenshot");
indexShortcut("INDEX Task Manager",   "Task manager",          "Ctrl+Shift+Esc", "taskmgr");

for (const w of workspace.windowList()) watch(w);

workspace.windowAdded.connect(w => { watch(w); push(); });
workspace.windowRemoved.connect(w => {
    const id = idOf(w);
    delete watched[id];
    delete order[id];
    push(id);
});
workspace.windowActivated.connect(() => push());
workspace.currentDesktopChanged.connect(() => push());
workspace.desktopsChanged.connect(() => push());
workspace.currentActivityChanged.connect(() => push());
workspace.screensChanged.connect(() => push());
workspace.virtualScreenGeometryChanged.connect(coverageChanged);

push();
