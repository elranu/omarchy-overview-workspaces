pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "OverviewMoves.js" as OverviewMoves

// Transient input state bridging the per-monitor PanelWindow surfaces during a
// window or workspace drag, per docs/cross-monitor-drag-contract.md.
//
// Qt's Drag/DropArea pair only works within one window -- its documentation
// states the result is "not specified" once a drag spans two -- and the overview
// is one layer-shell surface per monitor. What does survive that boundary is the
// pointer grab: the surface where the press happened keeps receiving motion
// after the cursor leaves it, with coordinates outside its own bounds. Nothing
// is lost, it is merely discarded. That is enough to bridge the surfaces by
// hand, and both overlays share a Quickshell process, so a singleton carries it.
//
// Scope is deliberately narrow. This binds no shortcut, touches no
// KeybindingService state, starts no capture, and owns the proxy image only for
// the duration of a drag.
Singleton {
    id: root

    property bool active: false
    // "window" drags one client onto a workspace card; "workspace" drags a whole
    // card onto a monitor. Consumers of one kind must ignore the other.
    property string kind: ""
    readonly property bool draggingWindow: root.active && root.kind === "window"
    readonly property bool draggingWorkspace: root.active && root.kind === "workspace"
    property string windowAddress: ""
    property int sourceWorkspaceId: -1
    // For a workspace drag, the monitor that currently owns the workspace.
    property string sourceWorkspaceMonitorName: ""
    // The surface the drag started on, used to tell a foreign card from a local
    // one -- not to route the drop.
    property string sourceMonitorName: ""

    // Pointer in global logical coordinates. Hyprland reports monitor positions
    // in the same space QML uses inside a surface, so converting is an offset
    // with no scale factor involved.
    property real pointerX: 0
    property real pointerY: 0

    // Bumped on every begin(). Asynchronous work started during a drag carries
    // the generation it belongs to and is discarded if the drag has since ended,
    // so a late callback cannot resurrect state or show a stale image.
    property int generation: 0

    // "<surface>:<workspace>" -> hit box in global coordinates. Two monitor
    // identities are kept apart on purpose:
    //
    //   surfaceMonitorName    the overlay rendering the hit box
    //   workspaceMonitorName  the monitor that owns the workspace
    //
    // With the default all-workspaces preview every overlay renders every card,
    // so the two differ routinely. Hit testing uses the surface and the
    // rectangle; the drop commit must use the workspace's owner, because a
    // workspace id alone never identifies a card -- trailing ids are allocated
    // per monitor and repeat across them.
    property var targets: ({})

    // Monitor sections ("<surface>:<monitor>") and, in per-monitor mode, whole
    // surfaces ("<monitor>"), in global coordinates. Only a workspace drag
    // reads them: a workspace is dropped on a monitor, not on a card.
    property var groups: ({})
    property var surfaces: ({})

    function begin(address, workspaceId, monitorName, w, h, px, py) {
        root.start("window", workspaceId, monitorName, w, h, px, py);
        root.windowAddress = String(address ?? "");
        root.active = true;
    }

    function beginWorkspace(workspaceId, workspaceMonitorName, surfaceMonitorName, w, h, px, py) {
        root.start("workspace", workspaceId, surfaceMonitorName, w, h, px, py);
        root.sourceWorkspaceMonitorName = String(workspaceMonitorName ?? "");
        root.active = true;
    }

    // Everything but going active, so each kind can finish its own fields
    // before consumers see the drag.
    function start(kind, workspaceId, monitorName, w, h, px, py) {
        root.generation += 1;
        root.kind = kind;
        root.windowAddress = "";
        root.sourceWorkspaceMonitorName = "";
        root.sourceWorkspaceId = workspaceId ?? -1;
        root.sourceMonitorName = String(monitorName ?? "");
        root.sourceWidth = w ?? 0;
        root.sourceHeight = h ?? 0;
        root.previewGrab = null;
        root.previewClip = Qt.rect(0, 0, 0, 0);
        // Seed the pointer from the press: going active with the previous drag's
        // coordinates would resolve hoveredTarget against a stale position for a
        // frame, flashing the highlight on the wrong card.
        root.pointerX = px ?? 0;
        root.pointerY = py ?? 0;
        root.targets = ({});
        root.groups = ({});
        root.surfaces = ({});
    }

    function publishGroup(surfaceMonitorName, monitorName, x, y, w, h) {
        if (!root.draggingWorkspace || !monitorName)
            return;
        const next = Object.assign({}, root.groups);
        next[`${surfaceMonitorName}:${monitorName}`] = { monitorName: String(monitorName), x: x, y: y, w: w, h: h };
        root.groups = next;
    }

    function publishSurface(monitorName, x, y, w, h) {
        if (!root.draggingWorkspace || !monitorName)
            return;
        const next = Object.assign({}, root.surfaces);
        next[String(monitorName)] = { monitorName: String(monitorName), x: x, y: y, w: w, h: h };
        root.surfaces = next;
    }

    function publishTarget(surfaceMonitorName, workspaceMonitorName, workspaceId, isTrailing, x, y, w, h) {
        if (!root.active || workspaceId === undefined || workspaceId === null)
            return;
        const next = Object.assign({}, root.targets);
        next[`${surfaceMonitorName}:${workspaceId}`] = {
            id: workspaceId,
            isTrailing: isTrailing === true,
            surfaceMonitorName: String(surfaceMonitorName ?? ""),
            workspaceMonitorName: String(workspaceMonitorName ?? ""),
            x: x,
            y: y,
            w: w,
            h: h
        };
        root.targets = next;
    }

    function updatePointer(gx, gy) {
        if (!root.active)
            return;
        root.pointerX = gx;
        root.pointerY = gy;
    }

    // The card under the pointer, or null. Reactive, so the destination overlay
    // can highlight and draw the proxy without polling.
    readonly property var hoveredTarget: root.draggingWindow
        ? OverviewMoves.hitTest(root.targets, root.pointerX, root.pointerY)
        : null

    // Where a dragged workspace would go, or "" when the pointer is over no
    // monitor or over the one that already owns it.
    readonly property string workspaceDropMonitorName: {
        if (!root.draggingWorkspace)
            return "";
        const name = OverviewMoves.workspaceDropMonitor(root.groups, root.surfaces, root.pointerX, root.pointerY);
        return name === root.sourceWorkspaceMonitorName ? "" : name;
    }

    // Snapshot of the dragged window, shown by the destination overlay so the
    // window itself appears to cross rather than a stand-in.
    //
    // The grab result is held, not just its url: grabToImage returns an
    // in-memory url that is valid only while the result object is alive. One
    // grab per drag -- the source monitor already captures this window live, and
    // a second continuous capture would cost GPU for nothing -- and it is
    // released on end().
    property real sourceWidth: 0
    property real sourceHeight: 0
    property var previewGrab: null
    // Part of the grabbed image to show. A workspace drag grabs its whole
    // overlay, since a card's windows are not children of the card, and crops.
    property rect previewClip: Qt.rect(0, 0, 0, 0)
    readonly property string previewUrl: root.previewGrab
        ? String(root.previewGrab.url ?? "")
        : ""

    function setPreview(grabResult, forGeneration) {
        // grabToImage answers asynchronously; by then the drag may be over or a
        // new one started. Applying it either way would show the wrong window.
        if (!root.active || forGeneration !== root.generation)
            return;
        root.previewGrab = grabResult ?? null;
    }

    function end() {
        root.active = false;
        root.kind = "";
        root.windowAddress = "";
        root.sourceWorkspaceId = -1;
        root.sourceMonitorName = "";
        root.sourceWorkspaceMonitorName = "";
        // Invalidates any callback still in flight, and lets the image go:
        // nothing displays it once the drag is over.
        root.generation += 1;
        root.previewGrab = null;
        root.targets = ({});
        root.groups = ({});
        root.surfaces = ({});
    }
}
