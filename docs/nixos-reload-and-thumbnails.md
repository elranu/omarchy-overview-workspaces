# NixOS 插件重载与缩略图故障记录

## 会话卡死的根因

旧版 `KeybindingService.qml` 在插件加载、配置变化和组件销毁时执行 `hyprctl reload`，并通过大量独立的 `hyprctl eval` 子进程安装按键。插件热扫描会销毁并重建 service，因此一次 `rescanPlugins` 可能同时触发：

- Hyprland 配置重载；
- 上百次 Hyprland IPC 调用；
- Overview 全屏 layer 和 screencopy 对象重建；
- 全局 Super+鼠标绑定被重写。

故障现场日志随后出现 `Bad file descriptor` 和 `error in client communication`，应用进程可能仍在运行，但 Hyprland 无法正常分发输入，因此所有窗口表现为卡死。

修复后：

- 插件生命周期不再调用 `hyprctl reload`；
- 加载时把所有绑定合并到一次 `hyprctl eval`；
- 组件销毁时不再自动修改 Hyprland；
- Overview 不再修改全局 Super+鼠标绑定。

## NixOS 缩略图兼容

- 移除 NixOS 环境缺失的 `Qt5Compat.GraphicalEffects` 硬依赖。
- 对窗口地址兼容带 `0x` 和不带 `0x` 两种格式。
- 总览关闭时设置 `captureSource: null` 和 `live: false`，不保留后台 screencopy context。
- 使用 `窗口地址|工作区ID` 作为窗口模型值。窗口迁移工作区时只重建该窗口的 delegate，不轮询调用 `captureFrame()`。

## 开发安全规则

开发目录未连接到 `~/.config/omarchy/plugins` 时，只进行离线修改。重新连接前必须确认：

```bash
rg -n 'hyprctl reload|captureFrame\(' . -g '*.qml'
```

正常结果应为空。不要在 Overview 打开或窗口拖动期间执行插件热扫描。

