const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(require.resolve('../WorkspaceBarConfig.js'), 'utf8'), context);
const migrate = context.removeDuplicateNativeWidget;
const configuredMode = context.configuredOverviewMode;
const legacyShellConfig = context.legacyShellConfig;
const requiresNativeRestore = context.requiresNativeWorkspaceNumberRestore;
const native = 'omarchy.workspaces';
const overview = 'hancore.overview-workspaces';

test('declares native replacement for install and disable lifecycle', () => {
    assert.equal(require('../manifest.json').omarchy.clonedFrom, native);
});

test('upgrades duplicates across sections while preserving settings and other widgets', () => {
    const config = { bar: { layout: {
        left: [{ id: 'omarchy.menu' }, { id: native }],
        center: [{ id: overview, sortMode: 'system', perMonitor: false }],
        right: [native, { id: 'omarchy.clock', format: 'HH:mm' }]
    } }, plugins: ['unrelated'], disabled: ['unrelated'] };
    assert.equal(migrate(config), true);
    assert.deepEqual(config, { bar: { layout: {
        left: [{ id: 'omarchy.menu' }],
        center: [{ id: overview, sortMode: 'system', perMonitor: false }],
        right: [{ id: 'omarchy.clock', format: 'HH:mm' }]
    } }, plugins: ['unrelated'], disabled: ['unrelated'] });
    assert.equal(migrate(config), false);
});

test('leaves native workspaces alone when Overview is not in the bar', () => {
    for (const config of [{}, { plugins: [overview], bar: { layout: { left: [native] } } }]) {
        const before = JSON.stringify(config);
        assert.equal(migrate(config), false);
        assert.equal(JSON.stringify(config), before);
    }
});

test('accepts string entries and missing sections', () => {
    const config = { bar: { layout: { left: [native, overview] } } };
    assert.equal(migrate(config), true);
    assert.deepEqual(config.bar.layout.left, [overview]);
    assert.equal(migrate(config), false);
});

test('reads the Omarchy 4 capability-scoped barConfig', () => {
    assert.equal(configuredMode({ barConfig: { layout: {
        left: [{ id: overview, sortMode: 'system' }],
        center: [],
        right: []
    } } }), 'system');
    assert.equal(configuredMode({ barConfig: { layout: {
        left: [],
        center: [overview],
        right: []
    } } }), 'legacy');
});

test('falls back to the legacy full-shell configuration', () => {
    const fullConfig = { bar: { layout: {
        left: [],
        center: [],
        right: [{ id: overview, sortMode: 'legacy' }]
    } } };
    const shell = { shellConfig: fullConfig };
    assert.equal(configuredMode(shell), 'legacy');
    assert.equal(legacyShellConfig(shell), fullConfig);
});

test('prefers scoped barConfig and rejects malformed or missing layouts', () => {
    const shell = {
        barConfig: { layout: { left: [{ id: overview, sortMode: 'system' }] } },
        shellConfig: { bar: { layout: { left: [{ id: overview }] } } }
    };
    assert.equal(configuredMode(shell), 'system');
    assert.equal(configuredMode(null), '');
    assert.equal(configuredMode({ barConfig: [] }), '');
    assert.equal(configuredMode({
        barConfig: [],
        shellConfig: { bar: { layout: { left: [overview] } } }
    }), '');
    assert.equal(configuredMode({ barConfig: { layout: [] } }), '');
    assert.equal(configuredMode({ barConfig: { layout: { left: [null, 7, {}] } } }), '');
    assert.equal(legacyShellConfig({ barConfig: {} }), null);
});

test('QML listens to both scoped and legacy config signals without warnings', () => {
    const source = fs.readFileSync(require.resolve('../KeybindingService.qml'), 'utf8');
    assert.match(source, /configuredOverviewMode\(root\.shell\)/);
    assert.match(source, /ignoreUnknownSignals:\s*true/);
    assert.match(source, /function onBarConfigChanged\(\)/);
    assert.match(source, /function onShellConfigChanged\(\)/);
    assert.match(source, /transitionScript\(root\.appliedMode, mode\)/);
    assert.match(source, /requiresNativeWorkspaceNumberRestore\(previousMode, nextMode\)/);
    assert.equal((source.match(/hancoreOverviewSuperListener:remove\(\)/g) ?? []).length, 2);
    assert.match(source, /hancoreOverviewSuperListener = nil/);
    assert.match(source, /hancoreOverviewSuperDown = nil/);
    assert.doesNotMatch(source, /hyprctl[^\n]*reload|reload[^\n]*hyprctl/);
});

test('restores native number bindings only for an owned legacy to system handoff', () => {
    assert.equal(requiresNativeRestore('legacy', 'system'), true);
    assert.equal(requiresNativeRestore('', 'system'), false);
    assert.equal(requiresNativeRestore('system', 'system'), false);
    assert.equal(requiresNativeRestore('legacy', 'legacy'), false);
    assert.equal(requiresNativeRestore('system', 'legacy'), false);
});

test('README documents the keepLoaded update activation step', () => {
    const manifest = require('../manifest.json');
    const readme = fs.readFileSync(require.resolve('../README.md'), 'utf8');
    assert.equal(manifest.keepLoaded, true);
    assert.match(readme, /omarchy restart shell/);
    assert.match(readme, /rescan alone does not replace that service instance/);
    assert.match(readme, /runtime unbind API has no plugin-owner\s+identity/);
});

test('manifest and settings panel report the same plugin version', () => {
    const version = require('../manifest.json').version;
    const panel = fs.readFileSync(require.resolve('../SettingsPanel.qml'), 'utf8');
    assert.match(panel, new RegExp(`pluginVersion:\\s*"${version.replaceAll('.', '\\.')}"`));
});
