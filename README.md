# Overview Workspaces

这是从 `oh-my-desktop` 的 Overview Workspaces 模块移植到 Omarchy Quattro 的完整窗口概览插件。

## 功能

- 插件自动注册单独 Win 按下/释放，打开/关闭 Overview
- Win+Tab / Win+Shift+Tab 进入 MRU 工作区切换模式
- 工作区分组、多显示器布局，并与 Omarchy 顶栏保持一致的工作区编号顺序（含空工作区）
- 使用 `ScreencopyView` 显示每个窗口的实时缩略图
- 鼠标点击工作区或窗口进行切换/聚焦
- 在工作区之间拖拽窗口
- 方向键、H/J/K/L、Tab、Enter、Escape 导航
- 每个显示器保留一个 trailing empty 新工作区
- Hyprland 工作区数据刷新、拖拽中的 pending 状态和窗口地址映射
- `WorkspaceOrder` 持久化工作区视觉顺序，并回收可复用的 Hyprland ID
- 默认使用“优化排序”：插件维护动态视觉顺序，Win+数字按 `1、2、3...` 视觉槽位切换，New workspace 永远在最后
- 可在顶部栏齿轮设置中切换“系统原生排序”：显示 Omarchy 的 `1–10`（包含空白槽位）以及真实存在的 `11+` 工作区

## 安装

```sh
omarchy plugin add https://github.com/iamcheyan/omarchy-overview-workspaces.git --enable
```

插件启用后，Hyprland 用户绑定会将 Win release 和 Win+Tab 路由到 Overview IPC。手动召唤：

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
```

打开顶部栏的插件设置面板，在“优化排序”和“系统原生排序”之间选择即可自动切换快捷键方案。
选择“优化排序”时，插件注册 `Win+1` 到 `Win+0` 来切换动态视觉槽位；选择“系统原生排序”时，
插件移除运行时绑定并重新加载 Hyprland，从而恢复用户原来的绑定。设置会保存在插件配置中。

如果设置面板不可用，也可以手动将下面片段加入用户的
`~/.config/hypr/bindings.lua`，并执行 `hyprctl reload`：

```lua
for slot = 1, 10 do
  local key = "code:" .. tostring(slot + 9)
  hl.unbind("SUPER + " .. key)
  hl.bind("SUPER + " .. key,
    hl.dsp.global("quickshell:workspaceSlot" .. tostring(slot)), {
      description = "Switch to workspace slot " .. tostring(slot)
    })
end
```

该绑定调用插件提供的 `workspaceSlot1` 到 `workspaceSlot10` 全局快捷键；
System 模式也通过同一入口解析原生空白槽位。

## 结构

核心移植文件来自 `oh-my-desktop/quickshell/modules/overview/`：

- `Overview.qml`：多屏 layer-shell 容器、键盘处理和 IPC 生命周期
- `OverviewWidget.qml`：工作区网格、壁纸、窗口拖拽和选择状态
- `OverviewWindow.qml`：窗口几何缩放、图标和 `ScreencopyView` 缩略图
- `WorkspaceNavigation.qml`：工作区导航、聚焦和拖拽提交
- `OverviewSwitchingController.qml`：Win+Tab 暂时切换与提交

同时移植了 `GlobalStates`、`HyprlandData` 和 `WorkspaceOrder`，并提供 Omarchy 插件所需的本地适配层。插件不修改 Omarchy 核心 shell 文件。

## 验证

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell Overview.qml OverviewWidget.qml OverviewWindow.qml
```

运行状态可以检查 overlay：

```sh
hyprctl layers | grep -A3 -B2 'quickshell:overview'
```
