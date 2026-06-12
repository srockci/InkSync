# InkSync

macOS 菜单栏应用，将 Apple Reminders 同步到墨水屏云端（zectrix-s3-epaper）。

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — 禁止任何商业用途。如需商用请联系作者获取授权。

## 功能特性

- **菜单栏常驻**，轻量不打扰
- **双向同步**：Apple Reminders ↔ 墨水屏云端
- **设备-列表映射**，灵活控制每个设备的同步范围
- **冲突解决策略**：时间戳优先 / Apple 优先 / 设备优先
- **周期备忘录**：按天/周/月/工作日/自定义间隔（含分钟、小时测试用）自动生成 Reminders
- **生成日志**：记录每次触发的成功/失败状态，支持 CSV 导出
- **失败通知中心**
- **首次启动引导**
- **关闭窗口后自动从 Dock 隐藏**，节省任务栏空间
- **菜单高度自适应内容**

## 同步流程

```
拉取（先状态同步）  →  重新拉取本地  →  推送（后条目同步）
  云端→本地完成状态     拉取后最新状态     本地→云端条目
```

### 推送匹配优先级

1. **cloudId 精确匹配**：本地有 `cloudId` 且云端存在 → 更新
2. **标题匹配收养**：本地无 `cloudId` 但云端有同名条目 → 收养（防重复）
3. **创建新条目**：都没有 → 创建

每条云端条目在单次同步中只被收养一次，避免 cloudId 映射互相覆盖。

### 拉取匹配

- 找到本地匹配项时回填 `cloudId`，下次推送走精确匹配
- 云端有完成状态但本地没有 → 标记本地完成
- 拉取不创建已完成条目到本地

## 架构

| 模块 | 职责 |
|------|------|
| `StatusBarController` | 菜单栏图标与 popover 窗口管理 |
| `MenuPopoverView` | 状态、设备、即时同步等快捷面板 |
| `SettingsWindow` | 设置窗口（API、策略、映射、通知） |
| `OnboardingWindow` | 首次启动引导 |
| `MappingManager` | 设备-列表映射与本地 calendar 加载 |
| `SyncEngine` | 差异计算、冲突解决、双向同步 |
| `EventKitManager` | 封装 Reminders 增删改查 |
| `APIClient` / `RealAPIClient` | 墨水屏云端 REST 客户端 |
| `RecurringEngine` | 周期备忘录定时触发引擎 |
| `RecurrenceScheduler` | 下次触发时间计算 |
| `RecurringReminderStore` | 周期规则持久化 |
| `RecurringGenerationLogger` | 生成日志持久化 |
| `NotificationManager` | 系统通知 |
| `AppConfig` | 用户偏好 |
| `SecureStorage` | ChaChaPoly 文件加密，避免 Keychain 弹窗 |
| `CloudIdStore` | 本地→云端 ID 映射持久化 |

## 周期备忘录

参考设计文档 `InkSync_RecurringReminders_Design.md`。支持：
- 周期类型：每天 / 每周（多选星期）/ 每月（多选日期，支持最后一天）/ 工作日 / 自定义（分钟/小时/天/周/月）
- 触发时间：小时 + 分钟
- 生效范围：开始日期 + 可选结束日期
- 高级选项：同名条目处理（跳过/覆盖/追加序号）、自动完成、标签
- 容错：5 分钟容错窗口，休眠唤醒后补发
- 触发流程：写入 Apple Reminders → 现有同步引擎自动推送到云端

## 云端 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/devices` | 设备列表 |
| GET | `/todos?deviceId=xxx` | 设备下的待办 |
| POST | `/todos` | 新建待办 |
| PUT | `/todos/{id}` | 更新待办 |
| PUT | `/todos/{id}/complete` | 标记完成 |
| PUT | `/todos/{id}/incomplete` | 取消完成 |
| DELETE | `/todos/{id}` | 删除待办 |

请求头：`X-API-Key: <your_key>`

## 配置

- API 地址：设置 → 云端账户
- API Key：同上（明文输入，SecureStorage 加密存储）
- 冲突策略：设置 → 同步策略
- 设备映射：设置 → 设备映射
- 周期规则：菜单栏 → 周期备忘

## 权限

- Reminders（EventKit）：用于读写本地待办
- 通知：用于同步完成/失败/冲突提示

## 安全

- API Key 使用 ChaChaPoly 对称加密存储于 `~/Library/Application Support/InkSync/secrets.dat`
- 加密密钥通过 HKDF 从 Bundle ID 派生
- 不用 Keychain，避免未签名应用的反复授权弹窗
- TextField 输入（`.textContentType(nil)`），不触发系统密码管理器联想

## 开发

```bash
open InkSync.xcodeproj
```

最低支持：macOS 13.0

## 文件结构

```
InkSync/
├── InkSyncApp.swift           # App 入口、AppDelegate
├── StatusBarController.swift  # 菜单栏
├── MenuPopoverView.swift      # 弹窗
├── SettingsWindow.swift       # 设置
├── OnboardingWindow.swift     # 引导
├── SyncEngine.swift           # 同步核心
├── SyncLogWindow.swift        # 同步日志窗口
├── SyncLogStore.swift         # 日志存储
├── SyncModels.swift           # 同步日志模型
├── EventKitManager.swift      # Reminders 增删改查
├── EKReminder+TodoItem.swift  # EKReminder → TodoItem 转换
├── EventKitError.swift        # EventKit 错误类型
├── APIClient.swift            # API 协议
├── RealAPIClient.swift        # 真实 API
├── SecureStorage.swift        # ChaChaPoly 加密存储
├── CloudIdStore.swift         # 本地→云端 ID 映射
├── MappingManager.swift       # 设备-列表映射管理
├── MappingConfig.swift        # 映射模型
├── MappingConfigView.swift    # 映射设置 UI
├── AppConfig.swift            # 用户偏好设置
├── TodoItem.swift             # TodoItem 模型
├── Models.swift               # 同步状态等模型
├── FlowLayout.swift           # macOS 13+ Layout 协议流式布局
├── SystemSettings.swift       # 系统设置快捷入口
├── NotificationManager.swift  # 系统通知
├── Recurring/                 # 周期备忘录
│   ├── RecurringReminder.swift
│   ├── RecurrenceRule.swift
│   ├── GenerationLog.swift
│   ├── RecurringReminderStore.swift
│   ├── RecurringGenerationLogger.swift
│   ├── RecurrenceScheduler.swift
│   ├── RecurringEngine.swift
│   ├── RecurringRemindersView.swift
│   ├── RecurringReminderEditView.swift
│   ├── RecurringLogView.swift
│   └── RecurringWindowControllers.swift
└── Assets.xcassets/
    └── AppIcon.appiconset/    # 应用图标
```