const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(require.resolve('../SearchKeys.js'), 'utf8'), context);
const { isTypedText } = context;

test('letters, digits, symbols and non-ASCII count as typed text', () => {
    for (const text of ['c', 'Z', '7', '/', '>', ' ', 'ñ', 'é'])
        assert.equal(isTypedText(text), true, JSON.stringify(text));
});

test('control characters from Enter, Escape, Tab, Backspace and Delete do not', () => {
    for (const text of ['\r', '\n', '\x1b', '\t', '\b', '\x7f', '', undefined, null])
        assert.equal(isTypedText(text), false, JSON.stringify(text));
});
