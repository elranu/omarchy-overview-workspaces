# Overview Workspaces

一个移植自 `oh-my-desktop` overview/workspaces 思路的 Omarchy Quattro 插件。

功能：

- 松开 Win 键时打开工作区总览
- 显示当前 Hyprland 工作区和窗口数量
- 鼠标点击切换工作区
- 方向键或 H/J/K/L 导航，Enter/Space 确认
- Escape 或再次松开 Win 键关闭

安装：

```sh
omarchy plugin add https://github.com/yourname/omarchy-overview-workspaces.git --enable
```

手动打开：

```sh
omarchy-shell shell summon hancore.overview-workspaces '{}'
```

插件只声明 `panel` 入口，工作区数据直接读取 Omarchy 当前 shell 提供的 `Quickshell.Hyprland` 模型，不修改 Omarchy 核心插件。
