import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "hancore.overview-workspaces"

    readonly property bool opened: settingsPanelLoader.item
        ? settingsPanelLoader.item.opened === true
        : false

    function applySettings() {
        // The overview singleton is initialized by SettingsPanel.qml. The
        // bar widget itself only owns the persisted settings entry.
    }
    function open() { if (settingsPanelLoader.item) settingsPanelLoader.item.open(); }
    function close() { if (settingsPanelLoader.item) settingsPanelLoader.item.close(); }
    function toggle() { if (settingsPanelLoader.item) settingsPanelLoader.item.toggle(); }
    function injectPanel() {
        if (!settingsPanelLoader.item) return;
        settingsPanelLoader.item.bar = root.bar;
        settingsPanelLoader.item.settings = root.settings;
        settingsPanelLoader.item.anchorItem = button;
        settingsPanelLoader.item.hostWidget = root;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()
    onSettingsChanged: { applySettings(); injectPanel(); }
    Component.onCompleted: {
        applySettings();
    }

    Loader {
        id: settingsPanelLoader
        active: true
        source: Qt.resolvedUrl("../SettingsPanel.qml")
        visible: false
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
    }

    IpcHandler {
        target: "hancore.overview-workspaces"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰒓"
        tooltipText: "Overview workspace order"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle();
        }
    }
}
