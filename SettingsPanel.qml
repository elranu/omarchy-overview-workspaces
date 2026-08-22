import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "."

Panel {
    id: root
    moduleName: "hancore.overview-workspaces"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property bool keybindingsEnabled: root.setting("keybindings", false) === true
    property bool bindingsApplied: false

    function open() { root.controller.show() }
    function close() { root.controller.hide() }
    function toggle() { root.opened ? root.close() : root.open() }

    function persistMode(mode) {
        GlobalStates.overviewSortMode = mode === "legacy" ? "legacy" : "system";
        var entry = { id: root.moduleName };
        for (var key in root.settings) {
            if (key !== "id")
                entry[key] = root.settings[key];
        }
        entry.sortMode = mode;
        root.settings = entry;
        if (root.hostWidget && "settings" in root.hostWidget)
            root.hostWidget.settings = entry;
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            root.bar.shell.updateEntryInline(root.moduleName, entry);
        root.setKeybindings(mode === "legacy");
    }

    function keybindingScript(optimized) {
        const commands = [];
        const interruptKeys = [
            "RETURN", "TAB", "SPACE", "BACKSPACE", "ESCAPE",
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
            "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
            "LEFT", "RIGHT", "UP", "DOWN", "GRAVE", "MINUS", "EQUAL",
            "COMMA", "PERIOD", "SLASH", "F1", "F2", "F3", "F4", "F5", "F6",
            "F7", "F8", "F9", "F10", "F11", "F12"
        ];

        commands.push("hyprctl eval 'hl.unbind(\"SUPER_L\"); hl.unbind(\"SUPER_R\"); hl.unbind(\"SUPER + SUPER_L\"); hl.unbind(\"SUPER + SUPER_R\"); hl.unbind(\"SUPER + TAB\"); hl.unbind(\"SUPER + SHIFT + TAB\")' >/dev/null 2>&1 || true");
        for (let slot = 1; slot <= 10; ++slot) {
            const keycode = slot + 9;
            commands.push(`hyprctl eval 'hl.unbind("SUPER + code:${keycode}")' >/dev/null 2>&1 || true`);
        }
        for (const key of interruptKeys)
            commands.push(`hyprctl eval 'hl.unbind("SUPER + ${key}")' >/dev/null 2>&1 || true`);

        // Reload first so stale runtime bindings and persistent user bindings
        // are normalized before this plugin installs its single set.
        commands.push("hyprctl reload >/dev/null 2>&1 || true");
        commands.push("hyprctl eval 'hl.unbind(\"SUPER_L\"); hl.unbind(\"SUPER_R\"); hl.unbind(\"SUPER + SUPER_L\"); hl.unbind(\"SUPER + SUPER_R\"); hl.unbind(\"SUPER + TAB\"); hl.unbind(\"SUPER + SHIFT + TAB\")' >/dev/null 2>&1 || true");
        commands.push("hyprctl eval 'hl.bind(\"SUPER_L\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_R\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_L\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, release = true, description = \"Overview Super state\" }); hl.bind(\"SUPER_R\", hl.dsp.global(\"quickshell:workspaceNumber\"), { ignore_mods = true, transparent = true, release = true, description = \"Overview Super state\" }); hl.bind(\"SUPER + TAB\", hl.dsp.global(\"quickshell:overviewNext\"), { description = \"Overview workspace next\" }); hl.bind(\"SUPER + SHIFT + TAB\", hl.dsp.global(\"quickshell:overviewPrev\"), { description = \"Overview workspace previous\" }); hl.bind(\"SUPER + SUPER_L\", hl.dsp.global(\"quickshell:overviewCommit\"), { release = true, description = \"Overview workspace commit\" }); hl.bind(\"SUPER + SUPER_R\", hl.dsp.global(\"quickshell:overviewCommit\"), { release = true, description = \"Overview workspace commit\" })' >/dev/null 2>&1 || true");

        if (optimized) {
            for (let slot = 1; slot <= 10; ++slot) {
                const keycode = slot + 9;
                commands.push(`hyprctl eval 'hl.unbind("SUPER + code:${keycode}"); hl.bind("SUPER + code:${keycode}", hl.dsp.global("quickshell:workspaceSlot${slot}"), { description = "Overview workspace slot ${slot}" })' >/dev/null 2>&1 || true`);
            }
            for (const key of interruptKeys)
                commands.push(`hyprctl eval 'hl.bind("SUPER + ${key}", hl.dsp.global("quickshell:superInterrupt"), { ignore_mods = true, non_consuming = true, transparent = true, description = "Overview Super interrupt" })' >/dev/null 2>&1 || true`);
        }
        return commands.join("; ");
    }

    function setKeybindings(enabled) {
        if (root.bindingsApplied && root.keybindingsEnabled === enabled)
            return;
        Quickshell.execDetached(["bash", "-lc", root.keybindingScript(enabled)]);
        root.bindingsApplied = true;
        root.keybindingsEnabled = enabled;
        var entry = { id: root.moduleName };
        for (var key in root.settings) {
            if (key !== "id")
                entry[key] = root.settings[key];
        }
        entry.keybindings = enabled;
        root.settings = entry;
        if (root.hostWidget && "settings" in root.hostWidget)
            root.hostWidget.settings = entry;
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            root.bar.shell.updateEntryInline(root.moduleName, entry);
    }

    function syncSettings() {
        const mode = root.setting("sortMode", "legacy") === "legacy" ? "legacy" : "system";
        GlobalStates.overviewSortMode = mode;
        root.setKeybindings(mode === "legacy");
    }

    Component.onCompleted: {
        root.syncSettings();
    }

    onSettingsChanged: root.syncSettings()

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(340))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()

            Column {
                id: content
                width: parent.width
                spacing: Style.space(10)

                Text {
                    text: "Overview workspace ordering"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                }

                Text {
                    text: "Choose the plugin's optimized order or Omarchy's native order."
                    color: Color.muted
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                }

                Repeater {
                    model: [
                        { key: "legacy", title: "Optimized order (recommended)", detail: "Plugin-managed dynamic order; Win+number follows slots 1, 2, 3... and New workspace stays last." },
                        { key: "system", title: "System native order", detail: "Matches Omarchy's native slots 1–10, including empty slots, plus real 11+ workspaces." }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: content.width
                        height: Style.space(58)
                        color: GlobalStates.overviewSortMode === modelData.key
                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                        border.width: 1
                        border.color: GlobalStates.overviewSortMode === modelData.key ? Color.accent : Color.muted

                        Column {
                            anchors.fill: parent
                            anchors.margins: Style.space(8)
                            spacing: Style.space(2)
                            Text {
                                text: modelData.title
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.body
                                font.bold: true
                            }
                            Text {
                                text: modelData.detail
                                color: Color.muted
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.persistMode(modelData.key)
                        }
                    }
                }
            }
        }
    }
}
