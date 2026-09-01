pragma Singleton
import QtQuick
import Quickshell

// Application lookup for the overview's search mode.
//
// This used to be a stub returning [], which meant the "Applications" section
// could never appear. It now queries DesktopEntries, the same source Omarchy's
// own services/AppLibrary.qml uses, so results agree with the Super+Space menu.
QtObject {
    id: root

    function iconSource(iconName, fallback) {
        const path = Quickshell.iconPath(iconName || fallback || "application-x-executable", true)
        return path ? (path.startsWith("/") ? `file://${path}` : path) : ""
    }

    function guessIcon(name) { return name || "application-x-executable" }

    function entryHaystack(entry) {
        return [
            entry?.name || "",
            entry?.genericName || "",
            entry?.comment || "",
            entry?.id || ""
        ].join(" ").toLowerCase();
    }

    // Ranked by how early the match lands: names starting with the query first,
    // then names containing it, then entries matching only on comment or id.
    // Ties break alphabetically.
    function fuzzyQuery(query) {
        const needle = String(query || "").toLowerCase().trim();
        if (needle.length === 0)
            return [];

        const values = DesktopEntries.applications.values || [];
        const scored = [];
        for (let i = 0; i < values.length; ++i) {
            const entry = values[i];
            if (!entry || entry.noDisplay)
                continue;
            const position = root.entryHaystack(entry).indexOf(needle);
            if (position < 0)
                continue;
            const name = String(entry.name || "");
            const nameIndex = name.toLowerCase().indexOf(needle);
            const score = nameIndex === 0 ? 0 : (nameIndex > 0 ? 1 : 2 + position);
            scored.push({ entry: entry, score: score, name: name });
        }

        scored.sort((a, b) => (a.score - b.score) || a.name.localeCompare(b.name));
        return scored.map(item => item.entry);
    }

    // uwsm-app keeps the app out of wayland-wm@.service, and gtk-launch resolves
    // ids with spaces or ones UWSM rejects. The .desktop suffix is required or
    // ids like org.telegram.desktop will not resolve. Same approach as AppLibrary.
    function launchApp(app) {
        const id = String(app?.id || "");
        if (id.length === 0)
            return false;
        Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", `${id}.desktop`]);
        return true;
    }
}
