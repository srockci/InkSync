# Changelog

All notable changes to InkSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-30

### Added

- **首次发布** - InkSync 墨水屏同步应用

#### 核心功能
- Menu bar 应用，无 Dock 图标
- EventKit 集成，读取 Apple Reminders
- 设备-列表映射管理（多设备、多列表）
- 映射唯一性约束（同一列表只能分配给一台设备）
- 配置持久化（UserDefaults）
- 列表变更自动适配

#### 同步引擎
- 定时轮询同步（5分钟间隔）
- 差异比对算法（toPush/toPull/conflicts）
- 冲突检测与解决（时间戳优先/Apple Reminders优先/设备优先）
- 双向同步（推送本地变更、拉取远程变更）
- 同步记录存储（JSON，保留30天）
- CSV 导出功能

#### 用户界面
- 菜单栏 Popover 界面
- 首次启动设置向导（4步）
- 设置窗口（API配置、设备映射、冲突策略、通知偏好）
- 同步记录窗口

#### 通知
- UserNotifications 集成
- 同步成功/失败/冲突通知
- 可配置的通知偏好

#### 测试
- 单元测试（差异算法、冲突解决、映射配置、同步日志）
- EventKit 集成测试

### 已知问题

- 实际墨水屏设备通信未实现（当前使用 MockAPIClient）
- 需要真实 API Key 才能连接云端服务
- LSUIElement 应用可能被 Mac App Store 拒绝，建议直接下载分发

### 技术栈

- macOS 13.0+
- Swift 5.0
- SwiftUI
- EventKit
- UserNotifications