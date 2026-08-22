import QtQuick
import Quickshell

Item {
    id: root

    // Injected by Omarchy's service loader.
    property var shell: null
    property string appliedMode: ""
    property bool restoring: false

    readonly property var interruptKeys: [
        "RETURN", "TAB", "SPACE", "BACKSPACE", "ESCAPE",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "LEFT", "RIGHT", "UP", "DOWN", "GRAVE", "MINUS", "EQUAL",
        "COMMA", "PERIOD", "SLASH", "F1", "F2", "F3", "F4", "F5", "F6",
        "F7", "F8", "F9", "F10", "F11", "F12"
    ]

    function configuredMode() {
        const config = root.shell?.shellConfig;
        const bar = config?.bar;
        const layout = bar?.layout;
        for (const section of ["left", "center", "right"]) {
            for (const entry of layout?.[section] ?? []) {
                if (entry?.id === "hancore.overview-workspaces")
                    return entry.sortMode === "system" ? "system" : "legacy";
            }
        }
        // This plugin's primary enable/disable switch is its bar entry. The
        // registry removes that entry when a bar-widget is disabled, even if
        // an old top-level plugins[] record remains for the service kind.
        return "";
    }

    // Injection invariant: every value interpolated into these strings comes
    // from the constant tables above (interruptKeys) or plain integers. The
    // result runs through `bash -lc` and Hyprland's Lua eval, so never feed
    // external data (window titles, user input, config strings) in here.
    // Keep the command list assembly that way.
    function bindingScript(optimized) {
        const commands = [];
        const unbindOverview = "hyprctl eval 'hl.unbind(\"SUPER_L\"); hl.unbind(\"SUPER_R\"); hl.unbind(\"SUPER + SUPER_L\"); hl.unbind(\"SUPER + SUPER_R\"); hl.unbind(\"SUPER + TAB\"); hl.unbind(\"SUPER + SHIFT + TAB\")' >/dev/null 2>&1 || true";

        commands.push(unbindOverview);
        for (let slot = 1; slot <= 10; ++slot) {
            const keycode = slot + 9;
            commands.push(`hyprctl eval 'hl.unbind("SUPER + code:${keycode}")' >/dev/null 2>&1 || true`);
        }
        // Reload restores the user's persistent Hyprland bindings. The second
        // unbind removes any old copy before installing this plugin's runtime
        // bindings, so repeated shell/plugin reloads cannot duplicate them.
        commands.push("hyprctl reload >/dev/null 2>&1 || true");
        commands.push(unbindOverview);

        commands.push("hyprctl eval 'hl.bind(\"SUPER_L\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_R\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_L\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, release = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_R\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, release = true, description = \"Overview Super state\" }); hl.bind(\"SUPER + TAB\", hl.dsp.global(\"quickshell:overviewNext\"), { description = \"Overview workspace next\" }); hl.bind(\"SUPER + SHIFT + TAB\", hl.dsp.global(\"quickshell:overviewPrev\"), { description = \"Overview workspace previous\" }); hl.bind(\"SUPER + SUPER_L\", hl.dsp.global(\"quickshell:overviewCommit\"), { release = true, description = \"Overview workspace commit\" }); hl.bind(\"SUPER + SUPER_R\", hl.dsp.global(\"quickshell:overviewCommit\"), { release = true, description = \"Overview workspace commit\" })' >/dev/null 2>&1 || true");

        // Both modes need the interrupt guard so Win+application shortcuts do
        // not accidentally toggle Overview when Win is released.
        // keyd presents a remapped CapsLock as a real Ctrl modifier.  Keep an
        // exact Ctrl+Super interrupt ahead of the legacy ignore_mods rule;
        // otherwise the generic Super+X rule can win and open Overview for a
        // shortcut that is meant for another service (for example Voxtype).
        for (const key of root.interruptKeys)
            commands.push(`hyprctl eval 'hl.bind("SUPER + CTRL + ${key}", hl.dsp.global("quickshell:superInterrupt"), { non_consuming = true, transparent = true, description = "Overview Ctrl+Super interrupt" })' >/dev/null 2>&1 || true`);

        for (const key of root.interruptKeys)
            commands.push(`hyprctl eval 'hl.bind("SUPER + ${key}", hl.dsp.global("quickshell:superInterrupt"), { ignore_mods = true, non_consuming = true, transparent = true, description = "Overview Super interrupt" })' >/dev/null 2>&1 || true`);

        if (optimized) {
            for (let slot = 1; slot <= 10; ++slot) {
                const keycode = slot + 9;
                commands.push(`hyprctl eval 'hl.unbind("SUPER + code:${keycode}"); hl.bind("SUPER + code:${keycode}", hl.dsp.global("quickshell:workspaceSlot${slot}"), { description = "Overview workspace slot ${slot}" })' >/dev/null 2>&1 || true`);
            }
        }
        return commands.join("; ");
    }

    function applyBindings() {
        if (!root.shell)
            return;
        const mode = root.configuredMode();
        if (mode === "") {
            if (root.appliedMode !== "") {
                root.restoreBindings();
                root.appliedMode = "";
            }
            return;
        }
        if (root.appliedMode === mode)
            return;
        Quickshell.execDetached(["bash", "-lc", root.bindingScript(mode === "legacy")]);
        root.appliedMode = mode;
    }

    function restoreBindings() {
        if (root.restoring)
            return;
        root.restoring = true;
        Quickshell.execDetached(["bash", "-lc", "hyprctl reload >/dev/null 2>&1 || true"]);
    }

    Component.onCompleted: Qt.callLater(root.applyBindings)
    Component.onDestruction: root.restoreBindings()
    onShellChanged: Qt.callLater(root.applyBindings)

    Connections {
        target: root.shell
        function onShellConfigChanged() {
            Qt.callLater(root.applyBindings);
        }
    }
}
