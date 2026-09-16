pragma Singleton
pragma ComponentBehavior: Bound
import "."

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "OverviewMoves.js" as OverviewMoves

Singleton {
    id: root

    property int pendingDragRefreshes: 0

    Timer {
        id: refreshAfterDragTimer
        interval: 90
        repeat: false
        onTriggered: {
            ServiceManager.workspace.updateAll();
            GlobalStates.refreshOverviewModel();
            root.pendingDragRefreshes -= 1;
            if (root.pendingDragRefreshes > 0)
                refreshAfterDragTimer.restart();
        }
    }
    function overviewModel() {
        if (OverviewSwitchingController.grabbed)
            return switchingModeModel();
        // The keyboard must walk exactly the cards on screen. Without this, in
        // per-monitor mode the arrow keys step onto workspaces belonging to another
        // monitor that this overlay does not draw.
        if (GlobalStates.overviewPerMonitor) {
            const anchor = GlobalStates.overviewAnchorMonitorName
                || Hyprland.focusedMonitor?.name
                || "";
            if (anchor.length > 0) {
                const scoped = ServiceManager.workspace.overviewWorkspaceEntriesForMonitor(anchor, true, {}, true, true);
                if (scoped.length > 0)
                    return scoped;
            }
        }
        return ServiceManager.workspace.overviewWorkspaceEntriesGroupedByMonitor();
    }

    function switchingModeModel() {
        const monitorName = GlobalStates.overviewAnchorMonitorName || Hyprland.focusedMonitor?.name || "";
        // All workspace navigation uses the same MRU order as the rendered grid.
        let model = ServiceManager.workspace.overviewWorkspaceEntriesForMonitor(monitorName, true, {}, true, false);
        if (model.length === 0)
            model = ServiceManager.workspace.overviewWorkspaceEntriesGlobal(true).filter(entry => !entry.isTrailingEmpty);
        return model;
    }

    function gridColumnsForModel(model) {
        return Math.min(Math.max(model.length, 1), Config.options.overview.columns);
    }

    function indexForWorkspace(model, wsId) {
        const idx = model.findIndex(entry => entry.id === wsId);
        return idx >= 0 ? idx : 0;
    }

    function currentWorkspaceId() {
        const anchorName = GlobalStates.overviewOpen ? GlobalStates.overviewAnchorMonitorName : "";
        const monitor = anchorName.length > 0
            ? ServiceManager.workspace.monitors.find(mon => mon.name === anchorName)
            : (Hyprland.focusedMonitor ?? Hyprland.monitors[0]);
        if (!monitor)
            return ServiceManager.workspace.activeWorkspace?.id ?? 1;
        return ServiceManager.workspace.monitorActiveWorkspaceId(monitor) || ServiceManager.workspace.activeWorkspace?.id || 1;
    }

    function focusedWorkspaceId() {
        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            return GlobalStates.overviewFocusedWorkspaceId;
        return root.currentWorkspaceId();
    }

    function selectWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewFocusedWorkspaceId = wsId;
    }

    function dispatchFocusWorkspace(wsId) {
        if (wsId < 1)
            return;
        const ws = ServiceManager.workspace.workspaceDataForId(wsId);
        if (ws?.monitor)
            Hyprland.dispatch(`hl.dsp.focus({monitor="${ws.monitor}"})`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
    }

    function navigateByIndex(delta, includeTrailing) {
        // Walking the selection on its own means the user has let go of the
        // window they were carrying.
        GlobalStates.overviewCarriedWindowAddress = "";
        const allowTrailing = includeTrailing ?? true;
        const model = allowTrailing
            ? root.overviewModel()
            : root.overviewModel().filter(entry => !entry.isTrailingEmpty);
        if (model.length === 0)
            return;

        const ws = root.focusedWorkspaceId();
        let idx = root.indexForWorkspace(model, ws);
        idx = (idx + delta + model.length) % model.length;
        root.selectWorkspace(model[idx].id);
    }

    function navigateGrid(deltaRow, deltaCol) {
        const model = root.overviewModel();
        const n = model.length;
        if (n === 0)
            return;

        const cols = root.gridColumnsForModel(model);
        if (deltaCol !== 0)
            root.navigateByIndex(deltaCol);
        else if (deltaRow !== 0)
            root.navigateByIndex(deltaRow * cols);
    }

    function focusedEntryIsTrailingEmpty() {
        const wsId = root.focusedWorkspaceId();
        if (wsId < 1)
            return false;
        const model = root.overviewModel();
        for (let i = 0; i < model.length; i++) {
            if (model[i].id === wsId)
                return !!model[i].isTrailingEmpty;
        }
        return false;
    }

    function focusedEntry() {
        const wsId = root.focusedWorkspaceId();
        if (wsId < 1)
            return null;
        const model = root.overviewModel();
        for (let i = 0; i < model.length; i++) {
            if (model[i].id === wsId)
                return model[i];
        }
        return null;
    }

    function focusMonitorForEntry(entry) {
        const monitorName = entry?.monitorName ?? "";
        if (monitorName.length > 0)
            Hyprland.dispatch(`hl.dsp.focus({monitor="${monitorName}"})`);
    }

    function commitSelectedWorkspace() {
        if (root.focusedEntryIsTrailingEmpty()) {
            const entry = root.focusedEntry();
            root.focusMonitorForEntry(entry);
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${entry.id} })`);
            if ((entry?.monitorName ?? "").length > 0)
                Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = "${entry.id}", monitor = "${entry.monitorName}" })`);
            return;
        }

        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            root.dispatchFocusWorkspace(GlobalStates.overviewFocusedWorkspaceId);
    }

    function resetOverviewDragState() {
        GlobalStates.overviewDraggingFromWorkspace = -1;
        GlobalStates.overviewDraggingTargetWorkspace = -1;
        GlobalStates.overviewDraggingTargetIsTrailing = false;
        GlobalStates.overviewDraggingTargetMonitor = "";
    }

    function beginWindowDrag(fromWorkspaceId) {
        GlobalStates.overviewDraggingFromWorkspace = fromWorkspaceId ?? -1;
    }

    function setDragTarget(workspaceId, isTrailing, workspaceMonitorName) {
        GlobalStates.overviewDraggingTargetWorkspace = workspaceId;
        GlobalStates.overviewDraggingTargetIsTrailing = isTrailing;
        GlobalStates.overviewDraggingTargetMonitor = String(workspaceMonitorName ?? "");
    }

    function clearDragTarget(workspaceId) {
        if (GlobalStates.overviewDraggingTargetWorkspace === workspaceId) {
            GlobalStates.overviewDraggingTargetWorkspace = -1;
            GlobalStates.overviewDraggingTargetIsTrailing = false;
            GlobalStates.overviewDraggingTargetMonitor = "";
        }
    }

    function commitWindowDrag(windowAddress, currentWorkspaceId, targetWorkspace, targetIsTrailing, targetMonitorHint) {
        root.resetOverviewDragState();
        if (!windowAddress || targetWorkspace === -1 || targetWorkspace === currentWorkspaceId)
            return false;

        // Counted by effective workspace: a window moved moments ago still sits
        // on its old workspace in Hyprland's data, and keyboard moves chain
        // faster than that data refreshes.
        const sourceVisibleWindows = ServiceManager.workspace.windowList
            .filter(win => win.mapped && !win.hidden && root.effectiveWorkspaceId(win) === currentWorkspaceId);
        const sourceIsEmptyAfterMove = sourceVisibleWindows.length <= 1;

        // A workspace id never identifies a card on its own: each monitor allocates
        // its trailing "new workspace" id independently, so the same number comes
        // back for several monitors. overviewModel() cannot settle it either --
        // it is scoped to the anchor monitor, so it holds neither another
        // screen's cards nor, on a non-anchor screen, the local ones.
        //
        // The caller resolved which monitor owns the target, so it says so.
        const targetMonitorName = String(targetMonitorHint ?? "");

        GlobalStates.setPendingWindowWorkspace(windowAddress, targetWorkspace);

        if (targetMonitorName.length > 0) {
            const pending = GlobalStates.overviewPendingWorkspaceMonitorById ?? {};
            const nextPending = Object.assign({}, pending);
            nextPending[targetWorkspace] = targetMonitorName;
            GlobalStates.overviewPendingWorkspaceMonitorById = nextPending;
        }

        if (targetIsTrailing) {
            const pendingOccupied = GlobalStates.overviewPendingOccupiedWorkspaces ?? [];
            const filtered = pendingOccupied.filter(entry => entry?.id !== targetWorkspace);
            filtered.push({
                id: targetWorkspace,
                monitorName: targetMonitorName,
                sourceWorkspaceId: currentWorkspaceId
            });
            GlobalStates.overviewPendingOccupiedWorkspaces = filtered;
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${windowAddress}" })`);
            if (targetMonitorName.length > 0)
                Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = "${targetWorkspace}", monitor = "${targetMonitorName}" })`);
        } else {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${windowAddress}" })`);
            if (targetMonitorName.length > 0)
                Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = "${targetWorkspace}", monitor = "${targetMonitorName}" })`);
        }

        if (sourceIsEmptyAfterMove) {
            const suppressed = GlobalStates.overviewSuppressedEmptyWorkspaceIds ?? [];
            if (!suppressed.includes(currentWorkspaceId)) {
                const next = suppressed.slice();
                next.push(currentWorkspaceId);
                GlobalStates.overviewSuppressedEmptyWorkspaceIds = next;
            }
        }

        GlobalStates.refreshOverviewModel();
        root.pendingDragRefreshes = 4;
        refreshAfterDragTimer.restart();
        return true;
    }

    function effectiveWorkspaceId(win) {
        const pending = GlobalStates.overviewPendingWindowWorkspaceByAddress ?? {};
        const address = String(win?.address ?? "");
        const pendingId = Number(pending[address] ?? pending[ServiceManager.workspace.normalizeAddress(address)] ?? 0);
        return pendingId > 0 ? pendingId : (win?.workspace?.id ?? -1);
    }

    // The window a keyboard move acts on: the one already being carried, else
    // the selected workspace's focused window -- the one the info bar names.
    // The pointer deliberately plays no part: a mouse resting or drifting over
    // some other window must never decide what a key press moves.
    function carryCandidate() {
        const data = ServiceManager.workspace;
        const carried = data.clientByAddress(GlobalStates.overviewCarriedWindowAddress);
        if (carried?.mapped && !carried.hidden)
            return carried;
        return data.focusedClientForWorkspace(root.focusedWorkspaceId());
    }

    function carryWindowToEntry(entry) {
        const win = root.carryCandidate();
        if (!win?.address || !entry || entry.id < 1)
            return false;
        const sourceId = root.effectiveWorkspaceId(win);
        GlobalStates.overviewCarriedWindowAddress = win.address;
        if (entry.id !== sourceId)
            root.commitWindowDrag(win.address, sourceId, entry.id, entry.isTrailingEmpty === true, entry.monitorName ?? "");
        // Follow the window when its new card is on this overlay, so repeated
        // presses keep pushing the same window along.
        if (root.overviewModel().some(candidate => candidate.id === entry.id))
            root.selectWorkspace(entry.id);
        return true;
    }

    // Moves the carried window to the neighbouring card, with the same
    // wrap-around and row width as arrow navigation.
    function carryWindowByGrid(deltaRow, deltaCol) {
        const win = root.carryCandidate();
        const model = root.overviewModel();
        if (!win || model.length === 0)
            return false;
        const sourceId = root.effectiveWorkspaceId(win);
        let index = model.findIndex(entry => entry.id === sourceId);
        if (index < 0)
            index = root.indexForWorkspace(model, root.focusedWorkspaceId());
        const delta = deltaCol !== 0 ? deltaCol : deltaRow * root.gridColumnsForModel(model);
        return root.carryWindowToEntry(model[OverviewMoves.stepIndex(model.length, index, delta)]);
    }

    // Moves the carried window to the card numbered `slot`, on any monitor.
    function carryWindowToSlot(slot) {
        let entries = ServiceManager.workspace.overviewWorkspaceEntries ?? [];
        if (entries.length === 0)
            entries = ServiceManager.workspace.overviewWorkspaceEntriesGlobal(true);
        return root.carryWindowToEntry(OverviewMoves.entryForSlot(entries, slot, GlobalStates.overviewSortMode));
    }

    // Sends a whole workspace, windows included, to another monitor. The owner
    // is recorded as pending first so the card changes sections at once rather
    // than when Hyprland's next event arrives.
    function moveWorkspaceToMonitor(workspaceId, monitorName) {
        const target = String(monitorName ?? "");
        const ws = ServiceManager.workspace.workspaceDataForId(workspaceId);
        if (workspaceId < 1 || target.length === 0 || !ws || ServiceManager.workspace.workspaceMonitorName(ws) === target)
            return false;
        const nextPending = Object.assign({}, GlobalStates.overviewPendingWorkspaceMonitorById ?? {});
        nextPending[workspaceId] = target;
        GlobalStates.overviewPendingWorkspaceMonitorById = nextPending;
        Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = "${workspaceId}", monitor = "${target}" })`);
        GlobalStates.refreshOverviewModel();
        root.pendingDragRefreshes = 4;
        refreshAfterDragTimer.restart();
        return true;
    }

    function focusWindow(windowData) {
        if (!windowData?.address)
            return;
        if (windowData?.workspace?.id > 0)
            GlobalStates.promoteWorkspaceMru(windowData.workspace.id);
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`);
    }
}
