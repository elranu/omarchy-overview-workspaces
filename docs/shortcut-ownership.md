# Shortcut ownership and lifecycle

## What the plugin owns

When `ranu.panorama` is enabled, the plugin is responsible only for:

- standalone Win: open or close the workspace Overview;
- Win+Tab and Win+Shift+Tab: cycle workspaces in Overview;
- Win+number: select an Overview workspace slot in legacy (optimized) ordering;
- `Ctrl+Shift+X`: arm force-kill mode. The system cursor is hidden and the
  JetBrainsMono Nerd Font close glyph `󰅖` is drawn next to the pointer. Clicking a
  window force-kills only that client; `Esc` or right-click cancels the mode
  without killing anything.

While a preview is being dragged, the plugin may temporarily suspend Win+mouse
move and resize, so dragging a preview does not also trigger Hyprland's own
move or resize. Those bindings must be restored when Overview closes.

## What the plugin must not touch

The plugin must not register or remove:

- catch-all observers for `SUPER + <any regular key>`;
- catch-all observers for `SUPER + CTRL + <any regular key>`;
- any shortcut the user has not delegated to the plugin;
- the command, callback, arguments, description, or options of user shortcuts.

So `Win+W`, `Win+Enter`, `Win+Space`, `Ctrl+Win+V`, and any other user-defined
combination must never be handled through an interrupt list.

## Detecting a standalone Win press

A standalone Win press must be detected from `input.keyboard.key` events:

1. When Win goes down, record a candidate state.
2. When any other key goes down, cancel the candidate, regardless of whether
   Ctrl, Win, or the regular key was pressed first.
3. Toggle the Overview only if the candidate is still valid when Win is released.

This avoids creating a batch of `SUPER + key` bindings that would compete with
user bindings just to recognize combinations.

## Enable, disable, and reload

The Win, Win+Tab, and Win+number bindings the plugin takes over exist only in
Hyprland's runtime state. When the plugin is disabled or destroyed, it uses a
single `hyprctl eval` to remove exactly its own bindings and then reinstalls
Omarchy's native Win+Tab and Win+Shift+Tab bindings, plus the native Win+number
bindings when optimized ordering was active. **Never call `hyprctl reload`** for
this: it reloads all of Hyprland.

The plugin does not save the user's previous bindings, so a custom user mapping
on one of those chords is replaced by Omarchy's native command on teardown. A
Hyprland config reload brings the user's own mapping back.

Hyprland's `hl.unbind("...")` does not track where a binding came from and can
remove user bindings. Only use it on chords the plugin explicitly owns; never on
a generic key list, and never to unbind user shortcuts by hand while diagnosing.

A Hyprland config reload clears all runtime bindings. The service listens for
`configreloaded`, clears `appliedMode`, and re-applies its bindings after a short
delay; without that, native bindings come back but the Overview bindings stay
missing while the service believes they are still installed.

## Diagnosing broken shortcuts or a missing bar

Collect evidence in this order before changing anything:

1. `ps`: confirm Quickshell is running.
2. `hyprctl layers`: confirm `omarchy-bar` exists.
3. `hyprctl binds -j`: save a snapshot of native and plugin bindings.
4. Compare with `$OMARCHY_PATH/default/hypr/bindings/` and the user's `bindings.lua`.
5. Check the Quickshell log for startups, exits, and QML errors.
6. Only once the shell is alive and the bindings exist, look at input devices or
   keyboard layouts.

A missing top bar usually means the Quickshell process is restarting (the log
shows `Exiting due to IPC request` followed by a new startup), not that the bar
component was hidden. Overlapping hot reloads and manual shell restarts widen
that window and can print `An instance of this configuration is already running`.

Stale runtime bindings left by an older plugin version are not removed by
updating the QML files. Clean them up with one controlled Hyprland config reload
followed by `omarchy restart shell`.

## Checks after every change

At minimum run:

```sh
npm test
hyprctl reload
hyprctl configerrors
hyprctl binds -j
```

Confirm that only the shortcuts the plugin declares carry an `Overview`
description at runtime, and that the native `SUPER + W`, `SUPER + RETURN`, and
`SUPER + SPACE` bindings still exist. Finally restart the shell and confirm the
results are unchanged after the plugin reloads.
