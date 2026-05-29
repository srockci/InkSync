# InkSync

macOS 纯菜单栏应用（无 Dock 图标），用于墨水屏设备与 Reminders 同步。

## 阶段 1

- 菜单栏图标（SF Symbols）
- 下拉面板（状态、设备列表、操作按钮）
- 占位数据与基础交互

## 运行

```bash
cd InkSync
open InkSync.xcodeproj
```

在 Xcode 中按 `Cmd+R` 运行，或：

```bash
xcodebuild -project InkSync.xcodeproj -scheme InkSync -configuration Debug build
open build/Debug/InkSync.app
```

## 验收

- 菜单栏出现六边形图标
- 点击展开下拉面板
- 点击空白处自动收起
- 无 Dock 图标（`LSUIElement = true`）
- 「立即同步」触发 3 秒 syncing 状态后恢复 idle
- 「退出 InkSync」正常退出应用
