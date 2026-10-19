const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../quickshell/DeviceWatch.qml'), 'utf8');
const block = source.slice(source.indexOf('id: btDevProc'));
const handler = block.match(/stdout: StdioCollector \{ onStreamFinished: \{([\s\S]*?)\n        \} \}/)[1];
const record = 'AA:BB:CC:DD:EE:FF=Headset';
const events = [];
const dev = { primed: true, btList: record, btPending: record, btStable: 2,
    settle() {}, btAnnounce(value, connected) { events.push([value, connected]); } };
const context = vm.createContext({ dev, text: '' });
function sample(text) { context.text = text; vm.runInContext(`(function() {${handler}\n})()`, context); }
for (let i = 0; i < 4; i++) sample('INDEX_BT_UNAVAILABLE');
assert.equal(dev.btList, record, 'backend failure preserves confirmed connection');
assert.equal(events.length, 0, 'timeouts must not announce disconnects');
for (let i = 0; i < 3; i++) sample(record);
assert.equal(events.length, 0, 'recovered backend must not announce a false reconnect');
for (let i = 0; i < 3; i++) sample('');
assert.equal(dev.btList, '', 'confirmed empty samples still detect disconnection');
assert.deepEqual(events, [[record, false]], 'real disconnect announced once');
for (let i = 0; i < 3; i++) sample(record);
assert.deepEqual(events, [[record, false], [record, true]], 'real reconnect announced once');
console.log('PASS: Bluetooth timeout/recovery and real disconnect/reconnect notifications');
