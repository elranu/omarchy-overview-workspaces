// Pure helpers for moving windows and workspaces from the Overview. Kept free
// of QML so the decisions can be tested with node.

// First hit box containing the point, or null. Accepts the registry object
// CrossMonitorDrag keeps ("key" -> box) or a plain array of boxes.
function hitTest(boxes, gx, gy) {
    const list = Array.isArray(boxes) ? boxes : Object.values(boxes ?? {});
    for (let i = 0; i < list.length; ++i) {
        const box = list[i];
        if (!box)
            continue;
        if (gx >= box.x && gx <= box.x + box.w && gy >= box.y && gy <= box.y + box.h)
            return box;
    }
    return null;
}

// The monitor a dragged workspace card would be sent to, or "".
//
// A monitor section wins, since it names its monitor exactly even when every
// overlay draws every monitor. Whole surfaces are only published in
// per-monitor mode, where a screen draws nothing but its own monitor, so
// anywhere on that screen is an unambiguous drop.
function workspaceDropMonitor(groups, surfaces, gx, gy) {
    const group = hitTest(groups, gx, gy);
    if (group)
        return String(group.monitorName ?? "");
    const surface = hitTest(surfaces, gx, gy);
    return surface ? String(surface.monitorName ?? "") : "";
}

// Omarchy binds workspaces 1..10 to keycodes 10..19 so they follow the
// physical number row whatever the layout. Shift changes the symbol those keys
// produce, never the keycode, so the same mapping holds with Shift held.
function slotFromKeycode(keycode) {
    const code = Number(keycode);
    return code >= 10 && code <= 19 ? code - 9 : 0;
}

// Wrap-around step through a list, matching the Overview's arrow navigation.
function stepIndex(count, index, delta) {
    if (count <= 0)
        return -1;
    const start = index >= 0 && index < count ? index : 0;
    return (((start + delta) % count) + count) % count;
}

// The card a number addresses. Occupied-only ordering numbers cards by visual
// slot, the way Win+number does; native ordering numbers them by workspace id,
// so a slot with no card still names a real workspace.
function entryForSlot(entries, slot, sortMode) {
    if (slot < 1)
        return null;
    const list = entries ?? [];
    if (sortMode === "legacy")
        return list[slot - 1] ?? null;
    return list.find(entry => entry?.id === slot && !entry.isTrailingEmpty)
        ?? { id: slot, isTrailingEmpty: false, monitorName: "" };
}
