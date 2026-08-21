pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function iconSource(iconName, fallback) {
        const path = Quickshell.iconPath(iconName || fallback || "application-x-executable", true)
        return path ? (path.startsWith("/") ? `file://${path}` : path) : ""
    }
    function guessIcon(name) { return name || "application-x-executable" }
    function fuzzyQuery(query) { return [] }
    function launchApp(app) { return false }
}
