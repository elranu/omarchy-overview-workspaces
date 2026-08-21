pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string root: "/usr/share/omarchy"
    readonly property string sumikaStateHome: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/omarchy-overview-workspaces`
}
