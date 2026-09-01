pragma Singleton
pragma ComponentBehavior: Bound
import "."
import QtQuick
import Quickshell
import Quickshell.Io
import "MenuIndex.js" as MenuIndex

// Busqueda dentro del command menu de Omarchy (el de Super+Space, id omarchy.menu).
//
// El modelo vive en MenuIndex.js, propio y autocontenido. No se importa el
// MenuModel.js de Omarchy porque los imports de JS en QML son estaticos y la
// ruta depende de $OMARCHY_PATH (en NixOS no es /usr/share/omarchy): una ruta
// fija romperia la carga del plugin entero en vez de degradar la busqueda.
//
// Lo importante son los guards: 144 de las 263 acciones del menu traen un `when:`
// (una condicion de shell). Sin evaluarlas ofreceriamos cosas como Hibernate en
// una maquina que no hiberna. guardScript() arma UN solo script bash que las
// resuelve todas de una pasada.
Singleton {
    id: root

    // Misma razon que arriba: el prefijo de Omarchy sale del entorno, no se
    // hardcodea. El fallback cubre el caso de que la variable no este seteada.
    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    readonly property string defaultPath: `${root.omarchyPath}/default/omarchy/omarchy-menu.jsonc`
    readonly property string userPath: `${Quickshell.env("HOME")}/.config/omarchy/extensions/omarchy-menu.jsonc`

    property var defaultItems: []
    property var userItems: []
    property var items: ({})
    property var itemOrder: []
    property var whenResults: ({})

    function rebuild() {
        const merged = MenuIndex.mergeMenuSources(root.defaultItems, root.userItems);
        root.items = merged.items;
        root.itemOrder = merged.itemOrder;
        root.evaluateGuards();
    }

    function evaluateGuards() {
        const script = MenuIndex.guardScript(root.items);
        if (!script) {
            root.whenResults = ({});
            return;
        }
        if (guardProc.running)
            return;
        guardProc.collected = "";
        guardProc.command = ["bash", "-lc", script];
        guardProc.running = true;
    }

    // Solo filas ejecutables. Un `menu` abre un submenu y un `link` navega: ni
    // uno ni otro tienen sentido como resultado suelto dentro del overview.
    function query(text, limit) {
        const needle = String(text || "").trim();
        if (needle.length === 0)
            return [];

        const order = root.itemOrder || [];
        const out = [];
        for (let i = 0; i < order.length; ++i) {
            const entry = MenuIndex.item(root.items, order[i]);
            if (!entry || entry.kind !== "action" || !entry.action)
                continue;
            // Para un `action` la visibilidad es solo su propio guard: Omarchy
            // tampoco mira los ancestros al resolver una fila ejecutable.
            if (entry.when && root.whenResults[entry.id] === false)
                continue;
            if (!MenuIndex.matchesQuery(entry, needle))
                continue;
            out.push({
                id: entry.id,
                label: entry.label,
                action: entry.action,
                description: entry.description || "",
                path: MenuIndex.parentPathFor(root.items, entry.id),
                score: MenuIndex.searchScore(root.items, entry, needle)
            });
        }
        out.sort((a, b) => a.score - b.score);
        return out.slice(0, limit || 6);
    }

    function runAction(action) {
        const command = String(action || "");
        if (command.length === 0)
            return false;
        Quickshell.execDetached(["bash", "-lc", command]);
        return true;
    }

    FileView {
        path: root.defaultPath
        watchChanges: true
        printErrors: false
        onLoaded: { root.defaultItems = MenuIndex.parseMenuJsonc(text()); root.rebuild(); }
        onFileChanged: reload()
    }

    FileView {
        path: root.userPath
        watchChanges: true
        printErrors: false
        onLoaded: { root.userItems = MenuIndex.parseMenuJsonc(text()); root.rebuild(); }
        onLoadFailed: { root.userItems = []; root.rebuild(); }
        onFileChanged: reload()
    }

    // Formato de salida del script: "<id>:<tag>:<0|1>" por linea. Solo nos
    // interesa el tag "w" (when); "c" (checked) es para el ✓ del menu.
    Process {
        id: guardProc
        property string collected: ""

        stdout: SplitParser {
            onRead: data => { guardProc.collected += data + "\n"; }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                return;
            const next = ({});
            const lines = guardProc.collected.split("\n");
            for (let i = 0; i < lines.length; ++i) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                const colon = line.lastIndexOf(":");
                if (colon < 0)
                    continue;
                const value = line.substring(colon + 1) === "1";
                const rest = line.substring(0, colon);
                const tagAt = rest.lastIndexOf(":");
                if (tagAt < 0)
                    continue;
                if (rest.substring(tagAt + 1) === "w")
                    next[rest.substring(0, tagAt)] = value;
            }
            root.whenResults = next;
        }
    }
}
