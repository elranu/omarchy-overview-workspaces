const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(require.resolve('../OverviewMoves.js'), 'utf8'), context);
const { hitTest, workspaceDropMonitor, slotFromKeycode, stepIndex, entryForSlot } = context;

const box = (monitorName, x, y, w, h) => ({ monitorName, x, y, w, h });

test('hit test accepts registry objects and arrays, edges included', () => {
    const left = box('DP-1', 0, 0, 100, 50);
    const right = box('eDP-1', 100, 0, 100, 50);
    assert.equal(hitTest({ a: left, b: right }, 150, 25), right);
    assert.equal(hitTest([left, right], 0, 0), left);
    assert.equal(hitTest([left], 100, 50), left);
    assert.equal(hitTest([left], 101, 25), null);
    assert.equal(hitTest(null, 1, 1), null);
});

test('a monitor section beats the surface it is drawn on', () => {
    // All-workspaces mode: DP-1's overlay draws both monitors' sections.
    const groups = [box('DP-1', 10, 10, 200, 100), box('eDP-1', 10, 130, 200, 100)];
    const surfaces = [];
    assert.equal(workspaceDropMonitor(groups, surfaces, 50, 150), 'eDP-1');
    assert.equal(workspaceDropMonitor(groups, surfaces, 50, 50), 'DP-1');
    // Blank space between sections is ambiguous there, so it names nothing.
    assert.equal(workspaceDropMonitor(groups, surfaces, 50, 120), '');
});

test('in per-monitor mode anywhere on the other screen is a drop on it', () => {
    const groups = [box('DP-1', 700, 400, 500, 300), box('eDP-1', 2300, 400, 500, 300)];
    const surfaces = [box('DP-1', 0, 0, 1920, 1080), box('eDP-1', 1920, 0, 1280, 800)];
    assert.equal(workspaceDropMonitor(groups, surfaces, 1950, 20), 'eDP-1');
    assert.equal(workspaceDropMonitor(groups, surfaces, 800, 500), 'DP-1');
    assert.equal(workspaceDropMonitor(groups, surfaces, 5000, 20), '');
});

test('number row keycodes map to slots 1..10 and nothing else does', () => {
    assert.equal(slotFromKeycode(10), 1);
    assert.equal(slotFromKeycode(18), 9);
    assert.equal(slotFromKeycode(19), 10);
    assert.equal(slotFromKeycode(9), 0);
    assert.equal(slotFromKeycode(20), 0);
    assert.equal(slotFromKeycode(undefined), 0);
});

test('stepping wraps both ways and recovers from a missing start', () => {
    assert.equal(stepIndex(4, 3, 1), 0);
    assert.equal(stepIndex(4, 0, -1), 3);
    assert.equal(stepIndex(4, 1, -8), 1);
    assert.equal(stepIndex(4, -1, 1), 1);
    assert.equal(stepIndex(0, 0, 1), -1);
});

test('occupied-only ordering addresses cards by visual slot', () => {
    const entries = [{ id: 7 }, { id: 3 }, { id: 12, isTrailingEmpty: true }];
    assert.equal(entryForSlot(entries, 1, 'legacy').id, 7);
    assert.equal(entryForSlot(entries, 3, 'legacy').isTrailingEmpty, true);
    assert.equal(entryForSlot(entries, 4, 'legacy'), null);
    assert.equal(entryForSlot(entries, 0, 'legacy'), null);
});

test('native ordering addresses workspaces by id, card or not', () => {
    const entries = [{ id: 7, monitorName: 'DP-1' }, { id: 3, isTrailingEmpty: true, monitorName: 'DP-1' }];
    assert.equal(entryForSlot(entries, 7, 'system').monitorName, 'DP-1');
    // A trailing card borrowing id 3 is not workspace 3.
    const three = entryForSlot(entries, 3, 'system');
    assert.equal(three.id, 3);
    assert.equal(three.isTrailingEmpty, false);
    assert.equal(three.monitorName, '');
});
