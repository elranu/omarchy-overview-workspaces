# Overview Workspaces

这是从 `oh-my-desktop` 的 Overview Workspaces 模块移植到 Omarchy Quattro 的完整窗口概览插件。

## 功能

- Win 键释放打开/关闭 Overview
- Win+Tab / Win+Shift+Tab 进入 MRU 工作区切换模式
- 工作区分组、多显示器布局和 Slot 编号
- 使用 `ScreencopyView` 显示每个窗口的实时缩略图
- 鼠标点击工作区或窗口进行切换/聚焦
- 在工作区之间拖拽窗口
- 方向键、H/J/K/L、Tab、Enter、Escape 导航
- 每个显示器保留一个 trailing empty 新工作区
- Hyprland 工作区数据刷新、拖拽中的 pending 状态和窗口地址映射
- `WorkspaceOrder` 持久化工作区视觉顺序，并回收可复用的 Hyprland ID

## 安装

```sh
omarchy plugin add https://github.com/iamcheyan/omarchy-overview-workspaces.git --enable
```

插件启用后，Hyprland 用户绑定会将 Win release 和 Win+Tab 路由到 Overview IPC。手动召唤：

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
```

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
