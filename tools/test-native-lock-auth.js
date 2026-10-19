// Exercise native lockscreen JavaScript without Qt, PAM, or a desktop VM.
// Run: node new/tools/test-native-lock-auth.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const qmlPath = path.join(__dirname, '../kde/look-and-feel/org.index.desktop/contents/lockscreen/LockScreen.qml');
const qml = fs.readFileSync(qmlPath, 'utf8');

// Same balanced-block approach as test-intro-playback.js. Only extract the
// named JS blocks; importing QML or copying its auth decisions would hide bugs.
function block(source, marker) {
    const start = source.indexOf(marker);
    assert.ok(start >= 0, `Missing QML block: ${marker}`);
    const open = source.indexOf('{', start);
    assert.ok(open >= 0, `Missing opening brace: ${marker}`);
    let depth = 1;
    let end = open + 1;
    for (; depth && end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    assert.equal(depth, 0, `Unclosed QML block: ${marker}`);
    return source.slice(open + 1, end - 1);
}

function binding(source, name) {
    // Include logical continuations: the heartbeat's running guard spans lines.
    const match = source.match(new RegExp(`(?:^|[;\\r\\n])\\s*${name}:\\s*([^;\\r\\n]+(?:\\r?\\n[ \\t]*(?:&&|\\|\\|)[^;\\r\\n]+)*)`));
    assert.ok(match, `Missing QML binding: ${name}`);
    return match[1].trim();
}

const timers = [...qml.matchAll(/\bTimer\s*\{/g)].map(match => block(qml.slice(match.index), match[0]));
function timerSource(id) {
    const matches = timers.filter(source => new RegExp(`\\bid:\\s*${id}\\b`).test(source));
    assert.equal(matches.length, 1, `Expected one Timer with id: ${id}`);
    return matches[0];
}

// The PAM heartbeat has no id. Identify its actual handler, rather than picking
// the first 1000 ms timer (which is the clock) or inventing an id for it.
const heartbeats = timers.filter(source => /onTriggered:\s*root\.ensureAuthentication\(/.test(source));
assert.equal(heartbeats.length, 1, 'Expected exactly one native authentication heartbeat');
const heartbeatSource = heartbeats[0];
const introPlayer = block(qml.slice(qml.lastIndexOf('MediaPlayer {', qml.indexOf('id: introVideo'))), 'MediaPlayer');

function harness() {
    const calls = { starts: 0, rejectedStarts: 0, stops: 0, responses: [], quit: 0, focus: 0, videoStops: 0 };
    const backend = { ready: false };
    const later = [];
    const context = vm.createContext({
        Window: { window: { active: true } },
        ScreenLocker: { Authenticator: { None: 0 }, Authenticators: { Idle: 0, Authenticating: 1 } },
        MediaPlayer: { PlayingState: 1, PausedState: 2, StoppedState: 0, InvalidMedia: 7, NoError: 0 },
        introConfig: { enabled: false, videoSource: '' },
        PasswordSync: { password: '' },
        defense: { visible: false, inputVisible: false, answerIndex: 0 },
        password: { forceActiveFocus() { calls.focus++; } },
        defensePassword: { forceActiveFocus() { calls.focus++; } },
        music: { play() {}, pause() {}, stop() {} },
        checkSound: { play() {} }, failSound: { play() {} }, successSound: { play() {} },
        Qt: { callLater(fn) { later.push(fn); }, quit() { calls.quit++; } },
        authenticator: {
            busy: false, inPasswordDelay: false, unlocked: false, state: 0,
            promptForSecret: '', prompt: '',
            startAuthenticating() {
                calls.starts++;
                // KDE can ignore startup before its worker exists. No prompt or
                // successful conversation is fabricated by an ignored call.
                if (!backend.ready) calls.rejectedStarts++;
                // The aggregate enters Authenticating even if its worker is not ready.
                this.state = context.ScreenLocker.Authenticators.Authenticating;
            },
            stopAuthenticating() {
                calls.stops++;
                this.state = context.ScreenLocker.Authenticators.Idle;
            },
            respond(response) { calls.responses.push(response); }
        }
    });
    context.root = context;
    const evaluate = code => vm.runInContext(code, context, { filename: qmlPath });
    const compile = code => evaluate(`(function() {${code}\n})`);
    const install = (target, source, name) => {
        const signature = source.match(new RegExp(`function ${name}\\(([^)]*)\\)`));
        assert.ok(signature, `Missing QML function: ${name}`);
        target[name] = evaluate(`(function(${signature[1]}) {${block(source, signature[0])}\n})`);
    };

    // Initialize root state and evaluate readonly bindings from the source,
    // including activeSurface and inputBlocked, on every access.
    const properties = qml.slice(0, qml.indexOf('IntroConfig {'));
    for (const [, readonly, name, expression] of properties.matchAll(
        /^\s*(readonly\s+)?property\s+(?:bool|string|int|double|real|color)\s+(\w+):[^\S\r\n]*([^\r\n]+)/gm
    )) {
        if (readonly) Object.defineProperty(context, name, { get: () => evaluate(expression) });
        else context[name] = evaluate(expression);
    }
    for (const name of ['focusPassword', 'updateClock', 'finishIntro', 'play', 'updateMusic',
        'ensureAuthentication', 'submit', 'showSuccess', 'showFailure', 'resolveResult', 'resetPrompt',
        'onPromptForSecretChanged', 'onPromptChanged', 'onFailed', 'onSucceeded']) {
        install(context, qml, name);
    }

    function makeTimer(source) {
        const trigger = /onTriggered:\s*\{/.test(source)
            ? compile(block(source, 'onTriggered:')) : compile(binding(source, 'onTriggered'));
        return {
            interval: Number(binding(source, 'interval')),
            repeat: /\brepeat:\s*true\b/.test(source), running: false,
            start() { this.running = true; },
            restart() { this.running = true; },
            stop() { this.running = false; },
            fire() {
                if (!this.running) return;
                if (!this.repeat) this.running = false;
                trigger();
            },
            queuedFire() { trigger(); }
        };
    }
    for (const id of ['checkingMinimum', 'verifyTimer', 'resetTimer', 'defenseTimer',
        'defenseAnswerTimer', 'unlockTimer', 'introTimeout', 'introWatchdog']) {
        context[id] = makeTimer(timerSource(id));
    }
    const watchdogSource = timerSource('introWatchdog');
    for (const [, name, value] of watchdogSource.matchAll(/property (?:int|bool) (\w+):\s*(\d+|true|false)/g)) {
        context.introWatchdog[name] = evaluate(value);
    }
    for (const name of ['resetProgress', 'checkProgress']) install(context.introWatchdog, watchdogSource, name);
    const heartbeatTrigger = compile(binding(heartbeatSource, 'onTriggered'));
    const heartbeat = {
        interval: Number(binding(heartbeatSource, 'interval')),
        repeat: /\brepeat:\s*true\b/.test(heartbeatSource),
        get running() { return evaluate(binding(heartbeatSource, 'running')); },
        fire() { if (this.running) heartbeatTrigger(); },
        queuedFire() { heartbeatTrigger(); }
    };
    const stateChanged = compile(block(introPlayer, 'onPlaybackStateChanged:'));
    function setPlayback(state) {
        context.introVideo.playbackState = state;
        context.playbackState = state; // MediaPlayer's unqualified own property.
        stateChanged();
    }
    context.introVideo = {
        playbackState: 0, position: 0, mediaStatus: 0, error: 0,
        play() { setPlayback(1); },
        stop() {
            assert.equal(context.introActive, false, 'finish intro before synchronous player callbacks');
            assert.equal(context.introTimeout.running, false, 'stop timeout before player');
            assert.equal(context.introWatchdog.running, false, 'stop watchdog before player');
            calls.videoStops++;
            setPlayback(0);
            context.finishIntro(); // Reentrant completion must be harmless.
        }
    };
    const completed = compile(block(qml, 'Component.onCompleted:'));
    return {
        root: context, calls, backend, heartbeat, completed, setPlayback,
        lockedChanged: compile(binding(qml, 'onLockedChanged')),
        flushLater() { while (later.length) later.shift()(); },
        prompt(value, secret = true) {
            context.authenticator[secret ? 'promptForSecret' : 'prompt'] = value;
            context[secret ? 'onPromptForSecretChanged' : 'onPromptChanged']();
        },
        introTick(ms, position = context.introVideo.position) {
            assert.equal(ms % context.introWatchdog.interval, 0);
            context.introVideo.position = position;
            for (let elapsed = 0; elapsed < ms; elapsed += context.introWatchdog.interval) {
                context.introWatchdog.fire();
            }
        }
    };
}

let cases = 0;
let failures = 0;
function test(name, run) {
    cases++;
    try {
        run(harness());
        console.log(`PASS native lock: ${name}`);
    } catch (error) {
        failures++;
        console.error(`FAIL native lock: ${name}\n${error.stack}`);
    }
}

function checking(h) {
    h.root.completed = true;
    h.root.authenticator.busy = true; // Exercise input during a backend state transition.
    h.prompt('Password:');
    h.root.PasswordSync.password = 'test-password';
    h.root.submit();
    assert.deepEqual(h.calls.responses, ['test-password']);
    assert.equal(h.root.phase, 'checking');
}

test('worker-not-ready startup retries via the actual heartbeat, then sends one response', h => {
    const r = h.root;
    h.completed();
    assert.equal(h.calls.starts, 1);
    assert.equal(h.calls.rejectedStarts, 1);
    r.PasswordSync.password = 'test-password';
    r.submit();
    assert.equal(r.phase, 'idle');
    assert.equal(r.status, '>_WAITING_FOR_AUTHENTICATION._');
    assert.equal(r.PasswordSync.password, 'test-password');
    assert.deepEqual(h.calls.responses, []);
    assert.equal(r.checkingMinimum.running, false);
    h.heartbeat.fire();
    assert.equal(h.calls.starts, 3);
    assert.equal(h.calls.rejectedStarts, 3);
    h.backend.ready = true;
    h.heartbeat.fire();
    assert.equal(h.calls.starts, 4, 'the heartbeat must retry the ignored startup');
    assert.equal(h.calls.rejectedStarts, 3);
    assert.equal(r.promptReady, false, 'worker readiness alone is not a prompt');
    assert.deepEqual(h.calls.responses, []);
    r.authenticator.busy = true;
    h.prompt('Password:');
    assert.equal(r.inputBlocked, false, 'a pending prompt permits input while KDE is busy');
    r.submit();
    r.submit();
    assert.deepEqual(h.calls.responses, ['test-password']);
    assert.equal(r.PasswordSync.password, '');
    assert.equal(r.promptReady, false);
    assert.equal(r.phase, 'checking');
    assert.equal(r.submitted, true);
    assert.equal(r.checkingMinimum.running, true);
    assert.equal(r.verifyTimer.running, true);
    h.heartbeat.fire();
    assert.deepEqual(h.calls.responses, ['test-password'], 'heartbeat never resends credentials');
    r.verifyTimer.fire();
    r.checkingMinimum.fire();
    assert.equal(r.phase, 'checking', 'elapsed animations cannot decide authentication');
    assert.equal(h.calls.quit, 0);
});

test('1000 ms repeating heartbeat runs only for a completed, active, locked native view', h => {
    const r = h.root;
    assert.equal(h.heartbeat.interval, 1000);
    assert.equal(h.heartbeat.repeat, true);
    h.heartbeat.fire();
    assert.equal(h.calls.starts, 0);
    r.completed = true;
    h.heartbeat.fire();
    assert.equal(h.calls.starts, 1);
    for (const [target, key, value] of [
        [r, 'locked', false], [r.Window.window, 'active', false],
        [r.Window, 'window', null], [r.authenticator, 'unlocked', true]
    ]) {
        const previous = target[key];
        target[key] = value;
        assert.equal(h.heartbeat.running, false, key);
        h.heartbeat.fire();
        assert.equal(h.calls.starts, 1, key);
        target[key] = previous;
    }
    h.heartbeat.fire();
    assert.equal(h.calls.starts, 2);
});

for (const secret of [true, false]) {
    test(`heartbeat never restarts a pending ${secret ? 'secret' : 'visible'} prompt, checking, or denied attempt`, h => {
        const r = h.root;
        h.backend.ready = true;
        h.completed();
        assert.equal(h.calls.starts, 1);
        const quietHeartbeat = state => {
            assert.equal(h.heartbeat.running, false, `${state}: stop the timer`);
            for (let tick = 0; tick < 3; tick++) h.heartbeat.fire();
            h.heartbeat.queuedFire(); // A previously queued event must also be guarded.
            assert.equal(h.calls.starts, 1, `${state}: no duplicate Authenticate`);
        };

        // KDE promptInternal clears busy while the worker is blocked awaiting
        // input. A busy-only guard therefore cannot prevent this deadlock.
        r.authenticator.busy = false;
        h.prompt('Password:', secret);
        assert.equal(r.promptReady, true);
        quietHeartbeat('pending prompt with busy=false');
        r.PasswordSync.password = 'wrong-password';
        r.submit();
        h.prompt('', secret);
        assert.equal(r.promptReady, false);
        assert.equal(r.phase, 'checking');
        quietHeartbeat('checking with prompt cleared and busy=false');
        r.onFailed(r.ScreenLocker.Authenticator.None);
        r.checkingMinimum.fire();
        assert.equal(r.phase, 'denied');
        quietHeartbeat('denied before reset');

        r.authenticator.inPasswordDelay = true;
        r.resetTimer.fire();
        assert.equal(r.phase, 'idle');
        quietHeartbeat('idle during PAM delay');
        r.authenticator.inPasswordDelay = false;
        assert.equal(h.heartbeat.running, true, 'retry resumes after PAM delay');
        h.heartbeat.fire();
        assert.equal(h.calls.starts, 2, 'start one fresh conversation for retry');
        h.prompt('Password:', secret);
        h.heartbeat.fire();
        assert.equal(h.calls.starts, 2, 'retry prompt also suppresses heartbeat');
        r.PasswordSync.password = 'retry-password';
        r.submit();
        assert.deepEqual(h.calls.responses, ['wrong-password', 'retry-password']);
        assert.equal(h.calls.quit, 0);
    });
}

test('ensureAuthentication guards direct calls, lock changes, and queued heartbeats', h => {
    const r = h.root;
    r.completed = true;
    r.ensureAuthentication();
    assert.equal(h.calls.starts, 1);
    for (const [target, key, value] of [
        [r, 'completed', false], [r, 'locked', false],
        [r.Window.window, 'active', false], [r.authenticator, 'unlocked', true],
        [r, 'promptReady', true], [r, 'phase', 'checking'], [r, 'phase', 'denied'],
        [r, 'phase', 'granted'], [r.authenticator, 'inPasswordDelay', true]
    ]) {
        const previous = target[key];
        target[key] = value;
        r.ensureAuthentication();
        h.lockedChanged();
        h.heartbeat.queuedFire();
        assert.equal(h.calls.starts, 1, `${key}=${value} must suppress every start site`);
        target[key] = previous;
    }
    h.lockedChanged();
    assert.equal(h.calls.starts, 2, 'eligible native lock change can start authentication');
});

test('only the active screen starts authentication on completion, waiting submit, or failure reset', h => {
    const other = harness();
    other.root.Window.window.active = false;
    h.completed();
    other.completed();
    assert.equal(h.calls.starts, 1);
    assert.equal(other.calls.starts, 0, 'inactive completion cannot start a worker');
    h.root.submit();
    other.root.submit();
    assert.equal(h.calls.starts, 2);
    assert.equal(other.calls.starts, 0, 'inactive waiting submit cannot start a worker');
    for (const view of [h, other]) {
        view.root.phase = 'denied';
        view.root.resetPrompt();
        assert.equal(view.root.phase, 'idle');
    }
    assert.equal(h.calls.starts, 3);
    assert.equal(other.calls.starts, 0, 'inactive reset cannot send a second Authenticate');
    // Repeated reset during a live prompt must not restart even the active view.
    h.prompt('Password:');
    h.root.resetPrompt();
    assert.equal(h.calls.starts, 3);
});

for (const secret of [true, false]) {
    const channel = secret ? 'secret' : 'visible';
    test(`initialization adopts an existing ${channel} prompt even with busy=true`, h => {
        const r = h.root;
        r.authenticator.state = r.ScreenLocker.Authenticators.Authenticating;
        r.authenticator.busy = true;
        r.authenticator[secret ? 'promptForSecret' : 'prompt'] = 'Existing prompt:';
        h.completed(); // No changed signal: a second view joins an existing prompt.
        assert.equal(h.calls.starts, 0, 'adopt the existing prompt before attempting a start');
        assert.equal(r.promptReady, true);
        assert.equal(r.secretPrompt, secret);
        assert.equal(r.pamPrompt, 'Existing prompt:');
        assert.equal(r.inputBlocked, false);
        r.PasswordSync.password = 'existing-response';
        r.submit();
        assert.deepEqual(h.calls.responses, ['existing-response']);
    });

    test(`initialization ignores retained ${channel} prompt in Idle and accepts a fresh native prompt`, h => {
        const r = h.root;
        h.backend.ready = true;
        r.authenticator.state = r.ScreenLocker.Authenticators.Idle;
        r.authenticator[secret ? 'promptForSecret' : 'prompt'] = 'Retained prompt:';
        h.completed();
        assert.equal(r.promptReady, false, 'completed must not adopt text from a finished conversation');
        assert.equal(r.pamPrompt, '');
        assert.equal(r.phase, 'idle');
        assert.equal(h.calls.starts, 1, 'active view starts a fresh native conversation');
        assert.equal(h.calls.rejectedStarts, 0);
        assert.equal(r.authenticator.state, r.ScreenLocker.Authenticators.Authenticating);
        assert.deepEqual(h.calls.responses, [], 'retained text does not trigger a response');
        // PAM can emit the same prompt text again; its actual changed handler
        // makes that fresh prompt ready after initialization has completed.
        h.prompt('Retained prompt:', secret);
        assert.equal(r.promptReady, true);
        assert.equal(r.pamPrompt, 'Retained prompt:');
        assert.equal(r.secretPrompt, secret);
        assert.equal(r.inputBlocked, false);
        h.heartbeat.fire();
        assert.equal(h.calls.starts, 1, 'the fresh prompt suppresses further starts');
        r.PasswordSync.password = 'fresh-response';
        r.submit();
        r.submit();
        assert.deepEqual(h.calls.responses, ['fresh-response']);
        assert.equal(r.PasswordSync.password, '');
        assert.equal(r.phase, 'checking');
        assert.equal(h.calls.quit, 0);
    });

    test(`clearing the ${channel} prompt cannot reset checking or enable another response`, h => {
        checking(h);
        h.flushLater();
        const focus = h.calls.focus;
        const status = h.root.status;
        h.prompt('', secret);
        h.flushLater();
        assert.equal(h.root.promptReady, false);
        assert.equal(h.root.phase, 'checking');
        assert.equal(h.root.status, status);
        assert.equal(h.root.checkingMinimum.running, true);
        assert.equal(h.root.verifyTimer.running, true);
        assert.equal(h.calls.focus, focus);
        h.root.submit();
        assert.deepEqual(h.calls.responses, ['test-password']);
        assert.equal(h.calls.quit, 0);
    });

    test(`an additional ${channel} OTP prompt returns to idle and accepts exactly one new response`, h => {
        checking(h);
        h.root.verifyTimer.fire();
        h.prompt('One-time code:', secret);
        assert.equal(h.root.phase, 'idle');
        assert.equal(h.root.status, '');
        assert.equal(h.root.promptReady, true);
        assert.equal(h.root.secretPrompt, secret);
        assert.equal(h.root.pamPrompt, 'One-time code:');
        assert.equal(h.root.checkingMinimum.running, false);
        assert.equal(h.root.verifyTimer.running, false);
        assert.equal(h.root.inputBlocked, false);
        h.root.PasswordSync.password = '123456';
        h.root.submit();
        h.root.submit();
        assert.deepEqual(h.calls.responses, ['test-password', '123456']);
        assert.equal(h.root.PasswordSync.password, '');
        assert.equal(h.root.phase, 'checking');
        assert.equal(h.calls.quit, 0);
    });
}

test('PAM password delay blocks submit even with a ready prompt and busy=true', h => {
    h.root.authenticator.busy = true;
    h.prompt('Password:');
    h.root.authenticator.inPasswordDelay = true;
    h.root.PasswordSync.password = 'test-password';
    assert.equal(h.root.inputBlocked, true);
    h.root.submit();
    assert.deepEqual(h.calls.responses, []);
    assert.equal(h.calls.starts, 0);
    assert.equal(h.root.PasswordSync.password, 'test-password');
    h.root.authenticator.inPasswordDelay = false;
    h.root.submit();
    assert.deepEqual(h.calls.responses, ['test-password']);
});

test('busy without a prompt blocks submit until a native prompt arrives', h => {
    h.root.authenticator.busy = true;
    h.root.PasswordSync.password = 'test-password';
    assert.equal(h.root.inputBlocked, true);
    h.root.submit();
    assert.equal(h.calls.starts, 0);
    assert.deepEqual(h.calls.responses, []);
    h.prompt('Password:');
    h.root.submit();
    assert.deepEqual(h.calls.responses, ['test-password']);
});

test('failed authentication stays locked through result, reset, and a queued unlock callback', h => {
    checking(h);
    h.root.onFailed(h.root.ScreenLocker.Authenticator.None);
    assert.equal(h.root.failCount, 1);
    assert.equal(h.root.pendingFailure, true);
    assert.equal(h.root.pendingSuccess, false);
    assert.equal(h.root.phase, 'checking');
    h.root.checkingMinimum.fire();
    assert.equal(h.root.phase, 'denied');
    assert.equal(h.root.resultText, '_ACCESS_DENIED._');
    assert.equal(h.root.resetTimer.running, true);
    assert.equal(h.root.unlockTimer.running, false);
    h.root.unlockTimer.queuedFire();
    assert.equal(h.calls.quit, 0);
    h.root.authenticator.busy = false;
    h.root.resetTimer.fire();
    assert.equal(h.root.phase, 'idle');
    assert.equal(h.root.pendingFailure, false);
    assert.equal(h.calls.starts, 1);
    assert.equal(h.calls.quit, 0);
    h.prompt('Password:');
    h.root.PasswordSync.password = 'retry-password';
    h.root.submit();
    assert.deepEqual(h.calls.responses, ['test-password', 'retry-password']);
    assert.equal(h.calls.quit, 0);
});

test('native success stops authentication immediately and waits for the checking minimum', h => {
    checking(h);
    h.root.pendingFailure = true;
    h.root.authenticator.unlocked = true;
    h.root.onSucceeded();
    assert.equal(h.calls.stops, 1);
    assert.equal(h.root.pendingSuccess, true);
    assert.equal(h.root.pendingFailure, false);
    assert.equal(h.root.phase, 'checking');
    assert.equal(h.heartbeat.running, false);
    assert.equal(h.calls.quit, 0);
    h.root.checkingMinimum.fire();
    assert.equal(h.root.phase, 'granted');
    assert.equal(h.root.unlockTimer.running, true);
    assert.equal(h.root.resetTimer.running, false);
    assert.equal(h.root.verifyTimer.running, false);
    h.root.unlockTimer.fire();
    assert.equal(h.calls.quit, 1);
});

test('native fingerprint/smartcard success needs no password submission and finishes intro', h => {
    h.root.introActive = true;
    h.completed();
    h.root.authenticator.unlocked = true;
    h.root.onSucceeded();
    assert.equal(h.calls.stops, 1);
    assert.deepEqual(h.calls.responses, []);
    assert.equal(h.root.submitted, false);
    assert.equal(h.root.introActive, false);
    assert.equal(h.calls.videoStops, 1);
    assert.equal(h.root.phase, 'granted');
    h.root.unlockTimer.fire();
    assert.equal(h.calls.quit, 1);
});

test('granted presentation cannot quit until the unlock timer sees native unlocked=true', h => {
    h.root.showSuccess();
    assert.equal(h.root.phase, 'granted');
    h.root.unlockTimer.fire();
    assert.equal(h.calls.quit, 0, 'local presentation is not unlock authority');
    h.root.authenticator.unlocked = true;
    h.root.unlockTimer.queuedFire();
    assert.equal(h.calls.quit, 1);
});

for (const state of [0, 1]) {
    test(`native intro with no progress in playback state ${state} ends at two seconds`, h => {
        h.root.introActive = true;
        h.completed();
        h.setPlayback(state);
        assert.equal(h.root.introWatchdog.interval, 500);
        h.introTick(1500);
        assert.equal(h.root.introActive, true);
        h.introTick(500);
        assert.equal(h.root.introActive, false);
        assert.equal(h.calls.videoStops, 1);
    });
}

test('native intro stalls at 1283 ms and finishes after six seconds without progress', h => {
    h.root.introActive = true;
    h.completed();
    for (const position of [200, 500, 900, 1283]) h.introTick(500, position);
    h.introTick(5500);
    assert.equal(h.root.introActive, true);
    h.introTick(500);
    assert.equal(h.root.introActive, false);
    assert.equal(h.calls.videoStops, 1);
});

test('advancing native intro repeatedly resets its stall budget', h => {
    h.root.introActive = true;
    h.completed();
    for (let position = 1000; position <= 10000; position += 1000) {
        h.introTick(500, position);
        h.introTick(5500);
        assert.equal(h.root.introActive, true);
    }
    assert.equal(h.calls.videoStops, 0);
});

test('native intro pause resets progress budget and resume grants six seconds', h => {
    h.root.introActive = true;
    h.completed();
    h.introTick(500, 1283);
    h.introTick(5500);
    h.setPlayback(2);
    assert.equal(h.root.introWatchdog.idleMs, 0, 'actual playback-state handler resets on pause');
    h.introTick(12000);
    assert.equal(h.root.introActive, true);
    h.setPlayback(1);
    h.introTick(5500);
    assert.equal(h.root.introActive, true);
    h.introTick(500);
    assert.equal(h.root.introActive, false);
});

test('finishIntro is idempotent across reentrant player callbacks and queued timers', h => {
    h.root.introActive = true;
    h.completed();
    h.root.finishIntro();
    h.root.finishIntro();
    h.root.introWatchdog.queuedFire();
    h.root.introTimeout.queuedFire();
    assert.equal(h.root.introActive, false);
    assert.equal(h.root.introWatchdog.running, false);
    assert.equal(h.root.introTimeout.running, false);
    assert.equal(h.calls.videoStops, 1);
    h.flushLater();
    assert.equal(h.calls.focus, 1);
    assert.equal(h.calls.quit, 0);
});

console.log(`Native lock: ${cases - failures}/${cases} behavior cases passed.`);
if (failures) process.exitCode = 1;
