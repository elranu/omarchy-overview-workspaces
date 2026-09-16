# hancore.overview-workspaces maintenance rules

## Never call `hyprctl reload` from the plugin lifecycle

This plugin runs inside Omarchy's Quickshell process. Plugin unload, hot reload,
and `Component.onDestruction` **must never call `hyprctl reload`**.

`hyprctl reload` reloads all of Hyprland instead of restoring this plugin's own
state, and can cause:

- a broken Wayland connection;
- Quickshell exiting and being relaunched repeatedly;
- a frozen desktop or unresponsive input during plugin hot reload;
- users believing that `omarchy restart shell` killed all their applications.

If the plugin temporarily changed keybindings, teardown may only undo this
plugin's own bindings, using a targeted `hyprctl eval`:

```qml
Quickshell.execDetached(["hyprctl", "eval", commands.join("; ")]);
```

Do not replace `unbind`/`bind` with a full Hyprland config reload. After changing
`KeybindingService.qml` or related lifecycle logic, run:

```bash
rg -n "hyprctl.*reload|reload.*hyprctl" .
```

The result must be empty unless it is an explicit manual maintenance command; in
particular it must never appear in `Component.onDestruction`, teardown callbacks,
or the plugin hot-reload path.

This rule comes from a real incident: after keybinding restoration was changed to
`hyprctl reload`, Shell restarts and plugin hot reloads broke the Wayland
connection. Switching back to `hyprctl eval` fixed it.
