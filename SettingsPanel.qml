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
    readonly property string pluginVersion: "0.1.3"
    readonly property color panelForeground: Color.popups.text
    readonly property color panelMuted: Util.alpha(Color.popups.text, 0.58)

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
    }

    function syncSettings() {
        const mode = root.setting("sortMode", "legacy") === "legacy" ? "legacy" : "system";
        GlobalStates.overviewSortMode = mode;
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
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()

            Item {
                id: content
                anchors.fill: parent
                implicitWidth: Math.max(menuColumn.implicitWidth, versionLabel.implicitWidth)
                implicitHeight: menuColumn.implicitHeight + versionLabel.implicitHeight + Style.space(12)

                Flickable {
                    id: menuScroller
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: versionLabel.top
                    anchors.bottomMargin: Style.space(8)
                    contentWidth: width
                    contentHeight: menuColumn.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: menuColumn
                        width: menuScroller.width
                        spacing: Style.space(10)

                        Text {
                            text: "Overview workspace ordering"
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: root.panelForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }

                        Text {
                            text: "Choose the plugin's optimized order or Omarchy's native order."
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: root.panelMuted
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
                                width: menuColumn.width
                                height: optionColumn.implicitHeight + Style.space(16)
                                color: GlobalStates.overviewSortMode === modelData.key
                                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                                    : Util.alpha(Color.popups.text, 0.06)
                                border.width: 1
                                border.color: GlobalStates.overviewSortMode === modelData.key ? Color.accent : Color.popups.border

                                Column {
                                    id: optionColumn
                                    anchors.fill: parent
                                    anchors.margins: Style.space(8)
                                    spacing: Style.space(2)
                                    Text {
                                        text: modelData.title
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        color: root.panelForeground
                                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                        font.pixelSize: Style.font.body
                                        font.bold: true
                                    }
                                    Text {
                                        text: modelData.detail
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        color: root.panelMuted
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

                Text {
                    id: versionLabel
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: `v${root.pluginVersion}`
                    color: root.panelMuted
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
