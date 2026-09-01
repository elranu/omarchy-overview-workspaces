// Indice buscable del command menu de Omarchy (el de Super+Space).
//
// Implementacion propia y autocontenida. Deliberadamente NO importa
// /usr/share/omarchy/shell/plugins/menu/MenuModel.js: los imports de JS en QML
// son estaticos, Omarchy resuelve su prefijo por $OMARCHY_PATH y en NixOS eso no
// es /usr/share/omarchy, asi que una ruta fija romperia la carga del plugin
// entero en vez de degradar la busqueda.
//
// Solo cubre lo necesario para buscar acciones ejecutables. Queda afuera a
// proposito todo lo que hace falta para *navegar* el menu: providers, filas de
// apps, rutas por alias y el marcador `checked`.

.pragma library

// ── Parseo del JSONC ───────────────────────────────────────────────────────

function stripJsonc(raw) {
    return String(raw || "")
        .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
        .replace(/,(\s*[}\]])/g, "$1");
}

function normalizeAliases(value) {
    if (Array.isArray(value))
        return value.filter(function (v) { return v; });
    if (typeof value === "string" && value)
        return [value];
    return [];
}

// Los ids con puntos definen la jerarquia: trigger.share.file cuelga de
// trigger.share. El kind se infiere: action -> action, target -> link, resto
// submenu.
function normalizeItem(id, raw) {
    var value = raw || {};
    var parent = value.parent;
    if (parent === undefined)
        parent = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(".") : "root";
    if (id === "root")
        parent = "";

    return {
        id: id,
        parent: parent,
        kind: value.action ? "action" : (value.target ? "link" : "menu"),
        label: value.label || id,
        description: value.description || "",
        action: value.action || "",
        aliases: normalizeAliases(value.aliases),
        when: value.when || ""
    };
}

function parseMenuJsonc(raw) {
    var stripped = stripJsonc(raw);
    if (!stripped.trim())
        return [];

    var parsed;
    try {
        parsed = JSON.parse(stripped);
    } catch (e) {
        return [];
    }
    if (typeof parsed !== "object" || parsed === null)
        return [];

    var source = (parsed.items && typeof parsed.items === "object" && !Array.isArray(parsed.items))
        ? parsed.items
        : parsed;

    var out = [];
    for (var id in source) {
        var entry = source[id];
        if (!entry || typeof entry !== "object" || Array.isArray(entry))
            continue;
        out.push(normalizeItem(id, entry));
    }
    return out;
}

// El jsonc del usuario pisa al default por id. Devuelve objetos nuevos en vez de
// escribir sobre los que recibe: viven en propiedades `var` de QML y el motor a
// veces descarta una escritura in-place.
function mergeMenuSources(defaultItems, userItems) {
    var items = {};
    var order = [];
    var sources = [defaultItems || [], userItems || []];

    for (var s = 0; s < sources.length; s++) {
        var list = sources[s];
        for (var i = 0; i < list.length; i++) {
            var entry = list[i];
            if (!items[entry.id])
                order.push(entry.id);
            items[entry.id] = entry;
        }
    }
    for (var k = 0; k < order.length; k++)
        items[order[k]].order = k;

    return { items: items, itemOrder: order };
}

function item(items, id) {
    return items && items[id] ? items[id] : null;
}

// ── Jerarquia ──────────────────────────────────────────────────────────────

function depthFor(items, id) {
    var depth = 0;
    var current = item(items, id);
    var guard = 0;
    while (current && current.parent && current.parent !== "root" && guard < 32) {
        depth += 1;
        current = item(items, current.parent);
        guard += 1;
    }
    return depth;
}

function pathFor(items, id) {
    var labels = [];
    var current = item(items, id);
    var guard = 0;
    while (current && current.id !== "root" && guard < 32) {
        labels.unshift(current.label);
        current = item(items, current.parent);
        guard += 1;
    }
    return labels.join(" › ");
}

function parentPathFor(items, id) {
    var entry = item(items, id);
    if (!entry || !entry.parent || entry.parent === "root")
        return "";
    return pathFor(items, entry.parent);
}

// ── Matching ───────────────────────────────────────────────────────────────

function searchableToken(value) {
    return String(value || "").replace(/[._-]+/g, " ");
}

function leafIdFor(id) {
    var parts = String(id || "").split(".");
    return parts.length > 0 ? parts[parts.length - 1] : id;
}

function nameSearchText(entry) {
    if (!entry)
        return "";
    var aliases = [];
    var values = Array.isArray(entry.aliases) ? entry.aliases : [];
    for (var i = 0; i < values.length; i++)
        aliases.push(searchableToken(values[i]));
    return [entry.label, searchableToken(leafIdFor(entry.id)), aliases.join(" ")].join(" ").toLowerCase();
}

function termInSearchWords(term, text) {
    var words = String(text || "").toLowerCase().split(/\s+/);
    for (var i = 0; i < words.length; i++) {
        if (words[i] === term)
            return true;
    }
    return false;
}

// Cada termino tiene que aparecer en el nombre o como palabra entera de la
// descripcion. Una subcadena suelta de la descripcion no alcanza: "in" no
// deberia traer todo lo que diga "install".
function matchesQuery(entry, query) {
    if (!entry || entry.id === "root")
        return false;

    var nameText = nameSearchText(entry);
    var descriptionText = String(entry.description || "").toLowerCase();
    var terms = String(query || "").toLowerCase().trim().split(/\s+/);

    for (var i = 0; i < terms.length; i++) {
        if (!terms[i])
            continue;
        if (nameText.indexOf(terms[i]) >= 0)
            continue;
        if (termInSearchWords(terms[i], descriptionText))
            continue;
        return false;
    }
    return true;
}

// Menor es mejor. El label exacto gana, despues prefijo, despues subcadena, y al
// final los que solo matchean por descripcion. Se desempata por profundidad y
// por orden de declaracion, para que el resultado sea estable.
function searchScore(items, entry, query) {
    var needle = String(query || "").toLowerCase().trim();
    var label = String(entry.label || "").toLowerCase();
    var nameText = nameSearchText(entry);
    var descriptionText = String(entry.description || "").toLowerCase();
    var score = 80;

    if (label === needle)
        score = entry.parent === "root" ? 2 : 0;
    else if (label.indexOf(needle) === 0)
        score = 10;
    else if (label.indexOf(needle) >= 0)
        score = 30;
    else if (nameText.indexOf(needle) >= 0)
        score = 40;
    else if (descriptionText.indexOf(needle) >= 0)
        score = 60;

    return score * 1000 + depthFor(items, entry.id) * 25 + (entry.order || 0);
}

// ── Guards ─────────────────────────────────────────────────────────────────

// Un unico script bash que resuelve todos los `when:` de una pasada e imprime
// "<id>:w:<0|1>" por linea. Se hace en batch porque son ~144 condiciones y un
// proceso por cada una tardaria muchisimo mas.
//
// A diferencia de Omarchy no se emite un prelude que cachee pacman: sus helpers
// (omarchy-pkg-present, omarchy-cmd-present) existen como binarios reales en
// $OMARCHY_PATH/bin, asi que las expresiones corren igual. Medido en esta
// maquina: 2.87 s contra 2.22 s del batch optimizado, con resultados identicos
// en los 144 guards. La diferencia no se nota porque esto corre en background y
// el resultado queda cacheado.
function guardScript(items) {
    var script = "";
    var ids = Object.keys(items || {});

    for (var i = 0; i < ids.length; i++) {
        var entry = items[ids[i]];
        if (!entry || !entry.when)
            continue;
        script += "if { " + entry.when + "; } >/dev/null 2>&1; then echo "
            + ids[i] + ":w:1; else echo " + ids[i] + ":w:0; fi\n";
    }
    return script;
}
