pragma Singleton
import QtQuick
import Quickshell

// Busqueda de aplicaciones para el modo search del overview.
//
// Antes esto era un stub que devolvia [] y hacia que la seccion "Applications"
// nunca apareciera. Ahora consulta DesktopEntries, el mismo origen que usa
// services/AppLibrary.qml de Omarchy, para que los resultados coincidan con los
// del menu de Super+Space.
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

    // Ordena por que tan "al principio" cae el match: primero los que empiezan
    // con la query, despues los que la tienen en el nombre, y al final los que
    // solo matchean por comment/id. Empates alfabeticos.
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

    // uwsm-app deja la app fuera de wayland-wm@.service, y gtk-launch resuelve
    // ids con espacios o que UWSM rechaza. El sufijo .desktop es obligatorio o
    // ids como org.telegram.desktop no resuelven. Mismo criterio que AppLibrary.
    function launchApp(app) {
        const id = String(app?.id || "");
        if (id.length === 0)
            return false;
        Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", `${id}.desktop`]);
        return true;
    }
}
