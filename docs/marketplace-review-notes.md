# 商店审核注意事项（Marketplace Review Notes）

> 2026-08-22 整理。来源：本插件 issue
> [#1401](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/1401)
> 及兄弟插件 #1468、#1428 的审核往返。供上架前自查与复审对照。

## 一、商店审核机制速览

1. **按精确 HEAD 审核**：维护者引用具体 commit SHA 复核。修复必须：上游提交 →
   issue 评论附 commit 链接 → 等按新 HEAD 复审。本地改完不推送 = 审核看不到。
2. **自动化基线**：扫描 `pkexec`/`sudo`/`systemctl`/`make` 模式，命中标
   `privilege`/`service-management` 能力。本仓基线 **passed、零能力标记**——这是优势，保持住。
3. **人工复审**只盯两类事：供应链完整性、资源与注入边界；语言精确到 `文件:行号`。

## 二、审核人在意的点（从三单反馈提炼）

| # | 关注点 | 出处 | 判例 |
|---|--------|------|------|
| 1 | 供应链固定：不 clone moving-HEAD、不以 root 构建下载物 | #1468 | unpinned remote-to-root path 被打回 |
| 2 | TOCTOU：校验后的用户可写路径不得再交特权步骤执行 | #1468 | make in user cache 被打回 |
| 3 | 资源无界：下载按声明大小截断 | #1428 | EOF 下载撑爆磁盘被打回 |
| 4 | **注入面：外部数据渲染必须显式 PlainText** | **#1401 本仓判例** | hyprctl clients 标题经 AutoText 可触发富文本资源加载 |
| 5 | 提权纪律：固定内联命令、用户显式触发 | #1428 ONNX | 固定串 pkexec 通过 |
| 6 | 卸载卫生：不在用户配置留悬挂钩子 | 提交清单 | explicit consent 条款 |
| 7 | 仓库卫生：无产物入库、README/license/preview 齐、版本递增 | 三单通用 | bot 校验 manifest 唯一性 |

## 三、本仓库反馈与修复状态

- 审核人 ryanrhughes（collaborator）：`HyprlandData.qml:557-573`、`OverviewWidget.qml`
  的窗口标题/类名经 `StyledText`（默认 `Text.AutoText`）渲染，本地应用可用 markup 形状
  的标题在常驻 shell 里触发富文本资源加载。
- 已修：`594826a` StyledText 改 `Text.PlainText`。HEAD 即此 commit，待维护者复核。

## 四、本仓库对照自查要点（侦察发现，复审重点）

- [ ] **PlainText 覆盖面**：#1401 判例点名的是 StyledText；需确认所有直接渲染
      `hyprctl clients/workspaces/activewindow` 字段的 Text 元素（不止 StyledText）
      都不会回落到 AutoText——审核人复核时会全文件扫。
- [ ] **service 入口的 bash -lc 动态拼装 hyprctl eval 字符串**（KeybindingService.qml，
      约 130+ 条 hl.bind/hl.unbind 一次性下发）：当前拼接内容为常量故安全，但模式上
      属「字符串拼命令」，任何未来插值都会变成注入点。建议加注释声明不变量或改列表传参。
- [ ] **Sumika 血统残留引用已损坏**：OverviewSearch.qml:86-119 引用
      `sumika-detach`/`sumika-restart`/`apps/sumika-bar`、WorkspaceNavigation.qml:26-31
      引用 `bin/sumika-applauncher`——这些二进制在本机不存在，对应功能实际不可用。
      上架后用户会当 bug 反馈；要么实现要么删功能入口。
- [ ] **workspace-order.json 写入门控依赖 `SUMIKA_APP_DIR` 环境变量且无锁**：
      isWriter 判定与旧命名强耦合，多实例并发写靠约定。建议换成插件自身 id 派生的显式开关。
- [ ] Wallpaper.qml 每 5s 无条件轮询 readlink；Config.qml `arbitraryRaceConditionDelay=50`
      魔数；Persistent.qml 死代码——不影响过审但属质量噪音。
- [x] 无 pkexec/sudo/keyd 类特权面；hyprctl 全部用户态 detached 运行。
- [ ] 无测试目录——#1428 的修复能被接受很快，部分原因是带了回归测试。
