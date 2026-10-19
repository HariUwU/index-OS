// Evaluate the actual QML startup gate in JS; no Qt, GUI, auth, or VM is launched.
// Run: node new/tools/test-greeter-intro.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const qml = fs.readFileSync(path.join(__dirname, '../greeter/greeter.qml'), 'utf8');
const config = fs.readFileSync(path.join(__dirname, '../greeter/IntroConfig.qml'), 'utf8');
assert.match(config, /property bool oncePerBoot: true/);
const gate = qml.slice(qml.lastIndexOf('            var play ='), qml.lastIndexOf('\n        }'));
assert.ok(gate.includes('INDEX_INTRO_BOOT') && gate.includes('if (play) startIntro()'));
const execute = new Function('surf', 'introConfig', 'Quickshell', 'startIntro',
    'bgMusic', 'passwordInput', 'introFocusTimer', gate);
let cases = 0;

for (const enabled of [false, true]) {
    for (const sourcePresent of [false, true]) {
        for (const oncePerBoot of [false, true]) {
            for (const bootFlag of [undefined, null, '', '0', '1', 'unexpected']) {
                for (const introFlag of [undefined, null, '', '0', '1', 'unexpected']) {
                    const calls = [];
                    const surf = { introActive: enabled && sourcePresent };
                    execute(surf, { oncePerBoot }, {
                        env: name => name === 'INDEX_INTRO_BOOT' ? bootFlag : introFlag
                    }, () => calls.push('intro'), { play: () => calls.push('music') },
                    { forceActiveFocus: () => calls.push('focus') },
                    { start: () => calls.push('focusTimer') });
                    const expected = enabled && sourcePresent && (!oncePerBoot || bootFlag === '1')
                        && (introFlag == null || introFlag === '' || introFlag === '1');
                    assert.deepEqual(calls, expected ? ['intro'] : ['music', 'focus', 'focusTimer']);
                    assert.equal(surf.introActive, expected);
                    cases++;
                }
            }
        }
    }
}

for (const oncePerBoot of [true, false]) {
    const calls = [];
    execute({ introActive: true }, { oncePerBoot }, { env: () => { throw Error('API missing'); } },
        () => calls.push('intro'), { play: () => calls.push('music') },
        { forceActiveFocus: () => calls.push('focus') }, { start: () => calls.push('focusTimer') });
    assert.deepEqual(calls, oncePerBoot ? ['music', 'focus', 'focusTimer'] : ['intro']);
    cases++;
}
console.log(`Greeter intro gate: ${cases} cases passed (including focus on skip).`);
