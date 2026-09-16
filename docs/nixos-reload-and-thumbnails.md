# NixOS plugin reload and thumbnail issues

## Root cause of the session freeze

Older versions of `KeybindingService.qml` ran `hyprctl reload` on plugin load,
config changes, and component destruction, and installed keys through many
separate `hyprctl eval` subprocesses. A plugin hot rescan destroys and recreates
the service, so a single `rescanPlugins` could trigger all at once:

- a Hyprland config reload;
- hundreds of Hyprland IPC calls;
- recreation of the full-screen Overview layer and screencopy objects;
- rewriting the global Super+mouse bindings.

The logs then showed `Bad file descriptor` and `error in client communication`.
Applications could still be running, but Hyprland could no longer dispatch
input, so every window appeared frozen.

After the fix:

- the plugin lifecycle never calls `hyprctl reload`;
- all bindings are applied in a single `hyprctl eval` on load;
- disable or destroy removes only the runtime bindings the plugin owns and
  restores Super+mouse move/resize, without reloading;
- while Overview is open, Super+mouse move/resize is temporarily removed so
  Hyprland cannot steal a preview drag.

## NixOS thumbnail compatibility

- Removed the hard dependency on `Qt5Compat.GraphicalEffects`, which is missing
  on NixOS.
- Window addresses are accepted with or without the `0x` prefix
  (`HyprlandData.normalizeAddress` / `clientByAddress`).
- When Overview closes, `captureSource: null`, so no background recording
  context is kept.
- Once Overview is open, `live: true`.

## Thumbnail strategy after workspace changes

### 2026-09-05 responsiveness improvements

- The plugin registers a `no_anim` layer rule matching only
  `quickshell:overview`; it is restored together with the keybindings after a
  config reload.
- The grid is created synchronously; the cross-frame Loader incubation and the
  info-bar fade-in were removed. Closing still destroys the grid and capture
  objects, to avoid suspend issues from restoring a hidden capture tree.
- Win+Tab creates a grid only on the screen that is actually shown.
- Removed the per-window 400 ms periodic `grabToImage`. Backups are taken only on
  the first frame, on drag, and on workspace changes, and concurrent backups of
  the same window are prevented.
- `ItemGrabResult` references are kept so in-memory image URLs stay valid; Qt's
  image keys must not be filtered by a `file:` prefix.
- Data refreshes are coalesced into 16 ms batches, and a pending refresh is not
  postponed by later events. The first frame still depends on compositor
  capture and is not guaranteed to be instant.

Each window preview is its own `ScreencopyView` per toplevel, not a screenshot of
the whole workspace. After a window is dragged or moved externally, its image
must appear on the target workspace immediately, without exposing the workspace
wallpaper in between.

### Quickshell constraints (do not trip on these again)

Behavior of `ScreencopyView` in `src/wayland/screencopy/view.cpp`:

- `setCaptureSource(null)` calls `destroyContext()` and resets `hasContent` to
  `false`.
- `setCaptureSource(same toplevel)` is a no-op and does not rebuild the context.
- When the compositor ends the stream it emits `stopped`, which also destroys the
  context and clears the image.
- `live: true` only keeps capturing inside `updatePaintNode`; if `!hasContent` or
  `!context`, paint returns immediately and **does not retry**.
- `captureFrame()` does nothing without a context.
- `ShaderEffectSource` cannot copy Wayland screencopy textures, so it cannot be
  used to freeze a frame.

Therefore: when a stream ends you must switch to a new recording context, but
before clearing the current `captureSource`, another visible image must already
be on screen.

### Approaches that failed

| Approach | Result |
|---|---|
| Model key `address\|workspaceId\|captureGeneration`, tearing down the whole delegate on move | Preview destroyed, workspace exposed, then recaptured |
| Rebuilding every window on the affected workspaces | Windows that did not move were torn down too and all became icons |
| Waiting another 220 ms after rebuilding before `arm` | Deliberately lengthened the blank period |
| Clearing `captureSource` when Overview closes or `visible === false` | Last frame lost; reopening showed only icons |
| Enabling `live` for only 500 ms | If the first frame failed, no image ever appeared |
| Binding a single `ScreencopyView` without rebuilding after the stream ends | Image stuck on the icon |

### Current approach

1. **The model identity is the window address.** `OverviewWidget`'s ScriptModel
   returns only addresses. Moving a window does not destroy its `OverviewWindow`;
   only its position changes.
2. **Record the target workspace as soon as the drag is released.**
   `GlobalStates.setPendingWindowWorkspace(address, targetId)`. While
   `hyprctl clients` still reports the old workspace, positioning already uses the
   target workspace. Suppressing the source workspace does not remove the window
   from the model.
3. **Positions use a sticky index.** While the new workspace is not in the grid
   yet, the window stays in its last valid cell and `visible` does not become
   `false`.
4. **Dual capture slots.** `preview0` / `preview1`. While the old slot is still
   showing, `arm` the new slot; once the new slot has `hasContent`, call
   `promoteSlot` and turn off the old one. Never tear down the old slot before the
   new one has captured.
5. **`grabToImage` when a drag starts.** This is a real-pixel backup. If the old
   stream ends before the new slot has a frame, this image is shown instead of
   the workspace wallpaper. Do not use `ShaderEffectSource` to freeze a
   `ScreencopyView`.
6. **`stopped` only starts the other slot; it never clears the current image and
   waits.** The watchdog only re-`arm`s when neither slot has content.

Key files: `OverviewWindow.qml` (dual slots + frozen frame), `OverviewWidget.qml`
(address model + pending positioning), `WorkspaceNavigation.qml` (writes pending
on release), `GlobalStates.qml` / `HyprlandData.qml` (writing pending state and
clearing it once confirmed).

### Do not revert these

- Do not encode the workspace ID or capture generation into the window model key.
- Do not tear down a `ScreencopyView` that is still being shown when a window moves.
- Do not use `ShaderEffectSource` to freeze Wayland previews.
- Do not set a window's `visible` to `false` when `hasContent === false` (it
  exposes the workspace card).

## Development safety rules

While the development directory is not linked into `~/.config/omarchy/plugins`,
only make offline changes. Before linking it again, confirm:

```bash
rg -n 'hyprctl reload' . -g '*.qml'
```

The result should normally be empty. Do not run a plugin hot rescan while
Overview is open or a window is being dragged.
