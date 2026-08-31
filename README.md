# Overview Workspaces

## 0.1.3

- Added the current plugin version to the workspace-order popup.
- Made the popup options responsive and scrollable when large text or a
  smaller display leaves less vertical space.
- Adapted the settings panel and overview scrim to theme-derived popup and
  background colors; removed the hard-coded dark scrim color.

![Overview after pressing Win](preview.png)

*First image — Press Win/Super to open the Overview. / 第一张：按下 Win/Super 后出现的 Overview。 / 1枚目：Win/Super キーを押して表示した Overview。*

![Overview while moving a window](preview-move.png)

*Second image — Click and drag windows freely inside Overview to move them between workspaces. / 第二张：可以在 Overview 中自由点击并拖拽窗口，在工作区之间移动。 / 2枚目：Overview 内でウィンドウを自由にクリック・ドラッグしてワークスペース間を移動できます。*

Overview Workspaces is an Omarchy Quattro experience-enhancement plugin. It provides a full-screen workspace overview with live window previews, wallpaper-backed workspace cards, dynamic workspace ordering, native workspace ordering, drag-and-drop movement, and automatic keyboard integration.

## Marketplace

Overview Workspaces has been approved and verified in the Omarchy plugin marketplace:
[open the published marketplace page](https://omarchyplugins.com/plugin.html?id=hancore.overview-workspaces).

## English

### Features

- Press the standalone Win/Super key to open or close Overview.
- Live `ScreencopyView` thumbnails for windows on every workspace.
- Wallpaper-backed workspace cards, including an opaque New workspace card.
- Empty workspaces remain visible when using native ordering.
- A New workspace card always stays at the end of each monitor's list.
- Mouse selection, window focusing, drag-and-drop, and multi-monitor layouts.
- Keyboard navigation with arrows, H/J/K/L, Tab, Enter, Space, and Escape.
- MRU workspace switching with Win+Tab and Win+Shift+Tab.
- Omarchy theme colors and configured icon font.
- No generic fallback icon is drawn over a window thumbnail when an app has no icon.

### Install

```sh
omarchy plugin add https://github.com/iamcheyan/omarchy-overview-workspaces.git --enable
```

After enabling, the plugin registers its Hyprland bindings automatically. Users do not need to edit `~/.config/hypr/bindings.lua`.

### Ordering modes

Open the gear button in the top bar to choose a mode.

**Optimized order (recommended)**

- Workspaces with windows receive dynamic visual slots `1, 2, 3...`.
- Win+1 through Win+0 follow those visual slots.
- The New workspace card always stays last.
- The top bar and Overview use the same order.

**System native order**

- Mirrors Omarchy's native workspace IDs.
- Empty workspaces 1–10 remain visible.
- Existing workspaces 11, 12, 13, and higher remain visible.
- Native IDs are not renumbered.
- Native Win+number behavior is restored while Overview and Win+Tab remain available.

Changing the mode updates the top bar, Overview, and keyboard behavior together.

### Keyboard integration and cleanup

The enabled plugin service registers standalone Win, Win+Tab, Win+Shift+Tab, optimized Win+number slots, and Super-interrupt guards for normal application shortcuts.

When the plugin is disabled or removed, the service is destroyed and Hyprland is reloaded so persistent user bindings are restored. Runtime bindings are not written into the user's Hyprland configuration.

### Manual summon and diagnostics

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
hyprctl layers | grep -A3 -B2 'quickshell:overview'
omarchy plugin list --json | jq '.[] | select(.id == "hancore.overview-workspaces")'
```

### Project files

- `Overview.qml` — Overview layer-shell surface and lifecycle.
- `OverviewWidget.qml` — workspace grid, wallpaper, borders, selection, and drag targets.
- `OverviewWindow.qml` — window geometry, live thumbnails, and app icons.
- `WorkspaceNavigation.qml` — keyboard navigation, focus, and drag commits.
- `OverviewSwitchingController.qml` — Win+Tab switching and commit behavior.
- `WorkspaceOrder.qml` — persistent optimized workspace ordering.
- `HyprlandData.qml` — workspace, monitor, and window state mapping.
- `SettingsPanel.qml` — ordering-mode settings panel.
- `KeybindingService.qml` — automatic shortcut registration and cleanup.

### Validation

```sh
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell \
  Overview.qml OverviewWidget.qml OverviewWindow.qml \
  SettingsPanel.qml KeybindingService.qml bar/widget.qml
```

---

## 中文

### 插件作用

Overview Workspaces 是一个用于 Omarchy Quattro 的体验增强插件。它提供完整的全屏工作区概览，包括实时窗口缩略图、壁纸工作区卡片、动态工作区排序、系统原生排序、窗口拖拽以及自动快捷键集成。

### 功能

- 单独按 Win/Super 键打开或关闭 Overview。
- 使用 `ScreencopyView` 显示每个工作区中的实时窗口缩略图。
- 工作区卡片显示壁纸，新工作区使用不透明背景。
- 系统原生排序模式下保留空白工作区。
- 每个显示器的最后始终保留一个“新工作区”。
- 支持鼠标选择、窗口聚焦、窗口拖拽和多显示器布局。
- 支持方向键、H/J/K/L、Tab、Enter、Space、Escape。
- 使用 Win+Tab 和 Win+Shift+Tab 按 MRU 顺序切换工作区。
- 使用 Omarchy 主题颜色和配置的图标字体。
- 应用没有图标时，不会在窗口缩略图上覆盖通用图标。

### 安装

```sh
omarchy plugin add https://github.com/iamcheyan/omarchy-overview-workspaces.git --enable
```

启用后插件会自动注册 Hyprland 快捷键，用户不需要手动修改 `~/.config/hypr/bindings.lua`。

### 排序模式

点击顶部栏齿轮按钮选择模式。

**优化排序（推荐）**

- 有窗口的工作区获得动态视觉槽位 `1、2、3...`。
- Win+1 到 Win+0 按视觉槽位切换。
- 新工作区始终在最后。
- 顶部栏和 Overview 使用完全一致的顺序。

**系统原生排序**

- 按照 Omarchy 的原生工作区 ID 显示。
- 空白的 1–10 工作区保留显示。
- 已存在的 11、12、13 及更高工作区也保留显示。
- 不重新编号，不改变系统真实 ID。
- Win+数字恢复系统行为，同时 Overview 和 Win+Tab 仍然可用。

切换模式会同时更新顶部栏、Overview 和快捷键行为。

### 快捷键与清理

插件启用后，service 会自动注册单独 Win、Win+Tab、Win+Shift+Tab、优化模式的 Win+数字，以及防止普通应用快捷键误触发 Overview 的拦截绑定。

插件禁用或卸载时，service 会被销毁并 reload Hyprland，恢复用户原来的持久化绑定。插件不会把运行时绑定写入用户的 Hyprland 配置文件。

### 手动启动和诊断

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
hyprctl layers | grep -A3 -B2 'quickshell:overview'
omarchy plugin list --json | jq '.[] | select(.id == "hancore.overview-workspaces")'
```

### 主要文件

- `Overview.qml`：Overview 的 layer-shell 界面和生命周期。
- `OverviewWidget.qml`：工作区网格、壁纸、描边、选择和拖拽目标。
- `OverviewWindow.qml`：窗口缩放、实时缩略图和应用图标。
- `WorkspaceNavigation.qml`：键盘导航、聚焦和拖拽提交。
- `OverviewSwitchingController.qml`：Win+Tab 切换逻辑。
- `WorkspaceOrder.qml`：优化排序的持久化。
- `HyprlandData.qml`：工作区、显示器和窗口数据映射。
- `SettingsPanel.qml`：排序模式设置面板。
- `KeybindingService.qml`：快捷键自动注册和清理。

### 验证

```sh
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell \
  Overview.qml OverviewWidget.qml OverviewWindow.qml \
  SettingsPanel.qml KeybindingService.qml bar/widget.qml
```

---

## 日本語

### プラグインについて

Overview Workspaces は Omarchy Quattro の操作体験を強化するプラグインです。ライブウィンドウサムネイル、壁紙付きワークスペースカード、動的な並び順、システム標準の並び順、ウィンドウのドラッグ、ショートカットの自動統合を提供します。

### 主な機能

- Win/Super キー単独で Overview を開閉。
- `ScreencopyView` によるライブウィンドウサムネイル。
- 壁紙付きのワークスペースカード。新しいワークスペースは不透明表示。
- システム標準モードでは空のワークスペースも表示。
- 各モニターの最後に常に「新しいワークスペース」を表示。
- マウス選択、ウィンドウのフォーカス、ドラッグ、マルチモニターに対応。
- 矢印キー、H/J/K/L、Tab、Enter、Space、Escape に対応。
- Win+Tab と Win+Shift+Tab による MRU 切り替え。
- Omarchy のテーマカラーと設定済みアイコンフォントを使用。
- アプリアイコンがない場合、サムネイル上に汎用アイコンを表示しない。

### インストール

```sh
omarchy plugin add https://github.com/iamcheyan/omarchy-overview-workspaces.git --enable
```

有効化後、Hyprland のショートカットは自動登録されます。`~/.config/hypr/bindings.lua` を手動編集する必要はありません。

### 並び順モード

トップバーの歯車ボタンからモードを選択します。

**最適化された並び順（推奨）**

- ウィンドウのあるワークスペースを動的な表示スロット `1、2、3...` に並べます。
- Win+1 から Win+0 で表示スロットを切り替えます。
- 新しいワークスペースは常に最後です。
- トップバーと Overview は同じ順序を使用します。

**システム標準の並び順**

- Omarchy の実際のワークスペース ID を表示します。
- 空の 1–10 も表示します。
- 実在する 11、12、13 以降も表示します。
- 番号の振り直しは行いません。
- Win+数字はシステム標準に戻し、Overview と Win+Tab は引き続き利用できます。

モード変更時、トップバー、Overview、ショートカットが同時に更新されます。

### ショートカットと後始末

有効化中、service が Win 単独、Win+Tab、Win+Shift+Tab、最適化モードの Win+数字、および通常のアプリショートカットとの競合を防ぐ割り込みバインドを自動登録します。

プラグインを無効化または削除すると service が破棄され、Hyprland を reload してユーザーの永続的なバインドを復元します。実行時バインドを設定ファイルへ書き込みません。

### 手動起動と診断

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
hyprctl layers | grep -A3 -B2 'quickshell:overview'
omarchy plugin list --json | jq '.[] | select(.id == "hancore.overview-workspaces")'
```

### 構成ファイル

- `Overview.qml`：Overview の layer-shell コンテナとライフサイクル。
- `OverviewWidget.qml`：ワークスペースグリッド、壁紙、枠線、選択、ドラッグ。
- `OverviewWindow.qml`：ウィンドウサイズ、ライブサムネイル、アプリアイコン。
- `WorkspaceNavigation.qml`：キーボード操作、フォーカス、ドラッグ確定。
- `OverviewSwitchingController.qml`：Win+Tab の切り替え処理。
- `WorkspaceOrder.qml`：最適化された並び順の永続化。
- `HyprlandData.qml`：ワークスペース、モニター、ウィンドウのデータ変換。
- `SettingsPanel.qml`：並び順設定パネル。
- `KeybindingService.qml`：ショートカットの登録と後始末。

### 検証

```sh
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell \
  Overview.qml OverviewWidget.qml OverviewWindow.qml \
  SettingsPanel.qml KeybindingService.qml bar/widget.qml
```
