pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application lookup for the overview's search mode.
//
// This used to be a stub returning [], which meant the "Applications" section
// could never appear. It now queries DesktopEntries, the same source Omarchy's
// own services/AppLibrary.qml uses, and applies the same launcher.hides filter,
// so results agree with the Super+Space menu.
Singleton {
    id: root

    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

    // NoDisplay alone is not enough: Omarchy hides a further list of desktop ids
    // that ship without it (btop, cmake-gui, avahi-discover and 35 others), so
    // filtering on NoDisplay only would surface entries its own launcher hides.
    property var hiddenIds: ({})

    function normalizeDesktopId(value) {
        return String(value || "").trim().replace(/\.desktop$/, "");
    }

    FileView {
        path: `${root.omarchyPath}/default/omarchy/launcher.hides`
        watchChanges: true
        printErrors: false
        onLoaded: root.loadHides(text())
        onFileChanged: reload()
        // Not fatal: without the list, application results simply include the
        // entries Omarchy's own launcher hides. Worth saying so out loud rather
        // than silently diverging from the Super+Space menu.
        onLoadFailed: {
            console.warn("hancore.overview-workspaces: no launcher.hides at "
                + `${root.omarchyPath}/default/omarchy/launcher.hides`
                + " -- hidden applications will show in search results");
            root.loadHides("");
        }
    }

    function loadHides(rawText) {
        const next = ({});
        const lines = String(rawText || "").split(/\n/);
        for (let i = 0; i < lines.length; ++i) {
            const id = root.normalizeDesktopId(lines[i]);
            if (id.length > 0)
                next[id] = true;
        }
        root.hiddenIds = next;
    }

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
            if (root.hiddenIds[root.normalizeDesktopId(entry.id)])
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
