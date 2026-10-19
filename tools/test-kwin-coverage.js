// Focused tests for background visibility and event-driven coverage updates.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../bridge/kwin-bridge.js'), 'utf8');
const signal = () => ({ callbacks: [], connect(fn) { this.callbacks.push(fn); }, emit() { this.callbacks.forEach(fn => fn()); } });
const d1 = { id: 'desktop-1', name: '1' }, d2 = { id: 'desktop-2', name: '2' };
let checks = 0;
function fixture(overrides = {}) {
    const window = {
        internalId: 'test-window', normalWindow: true, specialWindow: false, skipTaskbar: false,
        dialog: false, minimized: false, opacity: 1, output: { name: 'Virtual-1' },
        desktops: [d1], activities: [], caption: 'Test', desktopFileName: 'firefox', demandsAttention: false,
        area: { x: 0, y: 32, width: 1366, height: 736 },
        frameGeometry: { x: 0, y: 32, width: 1366, height: 736 },
        ...overrides,
    };
    for (const key of ['captionChanged', 'minimizedChanged', 'desktopsChanged', 'demandsAttentionChanged',
        'skipTaskbarChanged', 'frameGeometryChanged', 'opacityChanged', 'activitiesChanged']) window[key] = signal();
    const workspace = { desktops: [d1, d2], currentDesktop: d1, currentActivity: 'work',
        activeWindow: window, windowList: () => [window], clientArea: (_type, w) => w.area,
        currentDesktopForScreen: () => d1 };
    for (const key of ['windowAdded', 'windowRemoved', 'windowActivated', 'currentDesktopChanged',
        'desktopsChanged', 'currentActivityChanged', 'screensChanged', 'virtualScreenGeometryChanged']) workspace[key] = signal();
    const pushes = [];
    const context = vm.createContext({ workspace, KWin: { MaximizeArea: 1 }, registerShortcut() {},
        callDBus(_service, _object, _interface, method, value) { if (method === 'Push') pushes.push(JSON.parse(value)); } });
    vm.runInContext(source, context);
    return { window, workspace, pushes, context, coverage: () => pushes.at(-1).obscuredOutputs };
}
function check(label, overrides, expected) {
    assert.deepEqual(fixture(overrides).coverage(), expected, label); checks++;
}
check('maximized primary window', {}, ['Virtual-1']);
check('fullscreen primary window', { frameGeometry: { x: 0, y: 0, width: 1366, height: 768 } }, ['Virtual-1']);
check('uncovered floating window', { frameGeometry: { x: 200, y: 100, width: 640, height: 480 } }, []);
check('only the covered secondary screen pauses', { output: { name: 'Virtual-2' },
    area: { x: 1366, y: 0, width: 1280, height: 800 }, frameGeometry: { x: 1366, y: 0, width: 1280, height: 800 } }, ['Virtual-2']);
check('minimized windows do not obscure', { minimized: true }, []);
check('other desktops keep this desktop animated', { desktops: [d2] }, []);
check('all-desktop windows count', { onAllDesktops: true, desktops: [] }, ['Virtual-1']);
check('other activities do not obscure', { activities: ['other'] }, []);
check('transparent windows leave effects visible', { opacity: .8 }, []);
check('panels are excluded', { specialWindow: true }, []);
check('bundled translucent Konsole keeps effects visible', { desktopFileName: 'org.kde.konsole' }, []);
check('bundled translucent Alacritty keeps effects visible', { desktopFileName: 'Alacritty' }, []);
check('unknown client opacity is not assumed', { desktopFileName: 'unknown-app' }, []);
{
    const f = fixture();
    f.workspace.activeWindow = null; f.workspace.windowActivated.emit();
    assert.deepEqual(f.coverage(), ['Virtual-1'], 'coverage does not depend on keyboard focus'); checks++;
    f.workspace.activeWindow = f.window; f.workspace.windowActivated.emit();
    assert.deepEqual(f.coverage(), ['Virtual-1'], 'return to app pauses again'); checks++;
    f.window.minimized = true; f.window.minimizedChanged.emit();
    assert.deepEqual(f.coverage(), [], 'minimize resumes animation'); checks++;
}
{
    const f = fixture();
    f.workspace.activeWindow = { normalWindow: false, dialog: true, transient: true };
    f.workspace.windowActivated.emit();
    assert.deepEqual(f.coverage(), ['Virtual-1'], 'dialog focus preserves covered output'); checks++;
    f.workspace.currentDesktopForScreen = () => d2;
    f.workspace.currentDesktopChanged.emit();
    assert.deepEqual(f.coverage(), [], 'hidden window on another output desktop does not obscure'); checks++;
    f.window.desktops = [d2]; f.window.desktopsChanged.emit();
    assert.deepEqual(f.coverage(), ['Virtual-1'], 'visible window on independent output desktop counts'); checks++;
}
{
    const f = fixture({ frameGeometry: { x: 200, y: 100, width: 640, height: 480 } });
    const count = f.pushes.length;
    f.window.frameGeometry.x += 10; f.window.frameGeometryChanged.emit();
    assert.equal(f.pushes.length, count, 'small-window movement sends no redundant DBus update'); checks++;
    f.window.frameGeometry = { ...f.window.area }; f.window.frameGeometryChanged.emit();
    assert.deepEqual(f.coverage(), ['Virtual-1'], 'resize to cover output pauses animation'); checks++;
    f.workspace.windowRemoved.callbacks[0](f.window);
    assert.deepEqual(f.coverage(), [], 'removed window excluded before KWin list is updated'); checks++;
}
console.log(`PASS: ${checks} background coverage checks`);
