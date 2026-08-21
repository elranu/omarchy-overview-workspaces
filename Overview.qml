pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool overviewOpen: false
    property var workspaceModel: []

    function refresh() {
        const values = Hyprland.workspaces.values ?? [];
        root.workspaceModel = values
            .filter(ws => ws && ws.id > 0 && ws.id < 1000)
            .sort((a, b) => a.id - b.id);
    }

    function open(payload) {
        root.overviewOpen = true;
        root.refresh();
    }

    function close() {
        root.overviewOpen = false;
    }

    function toggle() {
        root.overviewOpen = !root.overviewOpen;
        if (root.overviewOpen) root.refresh();
    }

    function focusWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        root.close();
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.refresh(); }
    }

    IpcHandler {
        target: "hancore.overview-workspaces"

        function open() { root.open(); }
        function close() { root.close(); }
        function toggle() { root.toggle(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData
            screen: modelData
            visible: root.overviewOpen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "hancore-overview-workspaces"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.overviewOpen
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#cc101218"

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: root.overviewOpen
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        workspaceGrid.moveCurrentCell(-1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        workspaceGrid.moveCurrentCell(1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        workspaceGrid.moveCurrentCell(0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        workspaceGrid.moveCurrentCell(0, 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        const ws = workspaceGrid.selectedDelegate?.workspace;
                        if (ws) root.focusWorkspace(ws.id);
                        event.accepted = true;
                    }
                }

                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                        root.close();
                        event.accepted = true;
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 96, 1180)
                spacing: 20

                Text {
                    Layout.fillWidth: true
                    text: "Workspaces"
                    color: "#f5f5f5"
                    font.pixelSize: 30
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "Select a workspace  ·  Esc to close"
                    color: "#aeb5c2"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }

                GridView {
                    id: workspaceGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(560, Math.ceil(count / 4) * 144)
                    cellWidth: Math.floor(width / 4)
                    cellHeight: 144
                    model: root.workspaceModel
                    clip: true
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    currentIndex: {
                        const active = Hyprland.focusedWorkspace?.id ?? -1;
                        return Math.max(0, root.workspaceModel.findIndex(ws => ws.id === active));
                    }

                    property var selectedDelegate: contentItem.children[currentIndex] ?? null

                    function moveCurrentCell(dx, dy) {
                        if (count === 0) return;
                        const columns = 4;
                        const row = Math.floor(currentIndex / columns);
                        const col = currentIndex % columns;
                        const nextRow = Math.max(0, row + dy);
                        const nextCol = Math.max(0, Math.min(columns - 1, col + dx));
                        currentIndex = Math.max(0, Math.min(count - 1, nextRow * columns + nextCol));
                    }

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property var workspace: modelData
                        readonly property bool active: Hyprland.focusedWorkspace?.id === workspace.id
                        readonly property int windowCount: workspace.toplevels?.values?.length ?? 0
                        width: workspaceGrid.cellWidth - 14
                        height: workspaceGrid.cellHeight - 14
                        anchors.margins: 7
                        radius: 14
                        color: active ? "#3d5f91" : (mouse.containsMouse ? "#34404f" : "#222a35")
                        border.width: active ? 3 : 1
                        border.color: active ? "#8db7ff" : "#495565"

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${card.workspace.id}`
                                color: "#ffffff"
                                font.pixelSize: 36
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: card.windowCount === 1 ? "1 window" : `${card.windowCount} windows`
                                color: "#c4ccd8"
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.focusWorkspace(card.workspace.id)
                        }
                    }
                }
            }

            onVisibleChanged: {
                if (visible) {
                    root.refresh();
                    Qt.callLater(() => keyHandler.forceActiveFocus());
                }
            }
        }
    }
}
