// Run the actual QML watchdog and intro lifecycle functions without Qt or a VM.
// Run: node new/tools/test-intro-playback.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function block(source, marker) {
    const start = source.indexOf(marker);
    assert.ok(start >= 0, `Missing QML block: ${marker}`);
    const open = source.indexOf('{', start);
    let depth = 1;
    let end = open + 1;
    for (; depth && end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    assert.equal(depth, 0, `Unclosed QML block: ${marker}`);
    return source.slice(open + 1, end - 1);
}

function harness(relativePath) {
    const qml = fs.readFileSync(path.join(__dirname, relativePath), 'utf8');
    const timerStart = qml.lastIndexOf('Timer {', qml.indexOf('id: introWatchdog'));
    const timer = block(qml.slice(timerStart), 'Timer');
    const playerStart = qml.lastIndexOf('MediaPlayer {', qml.indexOf('id: introVideo'));
    const player = block(qml.slice(playerStart), 'MediaPlayer');
    const calls = { stop: 0, music: 0, focusTimer: 0 };
    const context = vm.createContext({
        MediaPlayer: { PlayingState: 1, PausedState: 2, StoppedState: 0,
            InvalidMedia: 7, NoError: 0 },
        surf: { introActive: true },
        introVideo: { playbackState: 0, position: 0, mediaStatus: 0, error: 0 },
        introWatchdog: {
            interval: Number(timer.match(/interval:\s*(\d+)/)[1]),
            repeat: /repeat:\s*true/.test(timer),
            running: false,
            start() { this.running = true; },
            stop() { this.running = false; }
        },
        bgMusic: { stop() {}, play() { calls.music++; } },
        introLayer: { opacity: 1, forceActiveFocus() {} },
        bgAudioOut: { volume: 0 },
        volTrack: { volValue: 0.5 },
        volSettings: { volume: 0.5 },
        passwordInput: { forceActiveFocus() {} },
        introFocusTimer: { start() { calls.focusTimer++; } }
    });
    for (const [, type, name, value] of timer.matchAll(/property (int|bool) (\w+):\s*(\d+|true|false)/g)) {
        context.introWatchdog[name] = type === 'bool' ? value === 'true' : Number(value);
    }
    for (const name of ['resetProgress', 'checkProgress']) {
        vm.runInContext(`introWatchdog.${name} = function() {${block(timer, `function ${name}(`)}}`, context);
    }
    for (const name of ['startIntro', 'endIntro', 'skipIntro']) {
        vm.runInContext(`surf.${name} = function() {${block(qml, `function ${name}(`)}}; var ${name} = surf.${name};`, context);
    }
    const stateChanged = new vm.Script(`(function() {${block(player, 'onPlaybackStateChanged:')}})()`);
    const trigger = new vm.Script(timer.match(/onTriggered:\s*([^\r\n]+)/)[1]);
    const setState = state => {
        context.introVideo.playbackState = state;
        // MediaPlayer handlers can reference their own properties unqualified.
        context.playbackState = state;
        stateChanged.runInContext(context);
    };
    context.introVideo.play = () => setState(1);
    context.introVideo.stop = () => {
        assert.equal(context.introWatchdog.running, false, 'disable watchdog before stopping media');
        assert.equal(context.surf.introActive, false, 'disable intro before synchronous stop callbacks');
        calls.stop++;
        setState(0);
        context.surf.endIntro(); // Simulate a reentrant completion callback.
    };
    return {
        ...context, calls, setState,
        tick(ms, position = context.introVideo.position) {
            assert.equal(ms % context.introWatchdog.interval, 0);
            context.introVideo.position = position;
            for (let elapsed = 0; elapsed < ms; elapsed += context.introWatchdog.interval) {
                if (!context.introWatchdog.running) continue;
                if (!context.introWatchdog.repeat) context.introWatchdog.running = false;
                trigger.runInContext(context);
            }
        },
        queuedTick() { trigger.runInContext(context); }
    };
}

let cases = 0;
for (const file of ['../greeter/greeter.qml', '../quickshell/lock/lock.qml']) {
    function test(name, run) {
        run(harness(file));
        cases++;
        console.log(`PASS ${file}: ${name}`);
    }
    test('advancing playback survives, then stalls at 1283 ms', h => {
        h.surf.startIntro();
        for (const position of [200, 500, 900, 1283]) h.tick(500, position);
        h.tick(5500);
        assert.equal(h.surf.introActive, true);
        h.tick(500);
        assert.equal(h.surf.introActive, false);
        assert.equal(h.calls.music, 1);
    });
    test('continued progress resets the stall budget', h => {
        h.surf.startIntro();
        for (let position = 1000; position <= 10000; position += 1000) {
            h.tick(500, position);
            h.tick(5500);
            assert.equal(h.surf.introActive, true);
        }
    });
    for (const state of [0, 1]) {
        test(`startup without progress in state ${state} ends within two seconds`, h => {
            h.surf.startIntro();
            h.setState(state);
            h.tick(1500);
            assert.equal(h.surf.introActive, true);
            h.tick(500);
            assert.equal(h.surf.introActive, false);
        });
    }
    test('stopped after progress also times out', h => {
        h.surf.startIntro();
        h.tick(500, 1283);
        h.setState(0);
        h.tick(5500);
        assert.equal(h.surf.introActive, true);
        h.tick(500);
        assert.equal(h.surf.introActive, false);
    });
    for (const pauseDuration of [0, 12000]) {
        test(`pause (${pauseDuration} ms) resets budget and resume grants six seconds`, h => {
            h.surf.startIntro();
            h.tick(500, 1283);
            h.tick(5500);
            h.setState(2);
            h.tick(pauseDuration);
            assert.equal(h.surf.introActive, true);
            h.setState(1);
            h.tick(5500);
            assert.equal(h.surf.introActive, true);
            h.tick(500);
            assert.equal(h.surf.introActive, false);
        });
    }
    for (const finish of ['endIntro', 'skipIntro']) {
        test(`${finish} before timeout is idempotent, including queued ticks`, h => {
            h.surf.startIntro();
            h.tick(500, 1283);
            h.tick(5500);
            h.surf[finish]();
            h.surf[finish]();
            h.tick(12000);
            h.queuedTick();
            assert.equal(h.introWatchdog.running, false);
            assert.equal(h.calls.stop, 1);
            assert.equal(h.calls.music, 1);
            assert.equal(h.calls.focusTimer, 1);
        });
    }
}
console.log(`Intro playback: ${cases} behavior cases passed.`);
