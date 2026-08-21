pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string currentBackgroundLink:
        `${Quickshell.env("HOME") || ""}/.local/state/omarchy/current/background`
    property url requestedUrl: ""
    property url readyUrl: ""

    function setBackground(path) {
        const resolved = String(path || "").trim();
        if (!resolved) {
            root.requestedUrl = "";
            root.readyUrl = "";
            return;
        }

        const url = resolved.startsWith("file://") ? resolved : `file://${resolved}`;
        root.requestedUrl = url;
        root.readyUrl = url;
    }

    function refresh() {
        if (!readBackground.running)
            readBackground.running = true;
    }

    Process {
        id: readBackground
        command: ["readlink", "-f", root.currentBackgroundLink]
        stdout: StdioCollector {
            onStreamFinished: root.setBackground(text)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
