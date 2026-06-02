# InkSync

macOS 菜单栏应用，将 Apple Reminders 同步到墨水屏云端。

## 功能

- 菜单栏常驻，轻量不打扰
- Apple Reminders 双向同步（添加、完成状态）
- 设备-列表映射，灵活控制同步范围
- 冲突解决策略（时间戳优先 / Apple 优先 / 设备优先）
- 同步日志与导出
- 失败通知中心
- API Key 本地加密存储（CryptoKit）
- 关闭窗口后自动从 Dock 隐藏

## 截图

点击菜单栏图标即可呼出操作面板。

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
| `MappingConfig` | 映射数据模型 |
| `SyncModels` | DiffResult、冲突检测与解决 |
| `SyncLogStore` | 同步日志持久化 |
| `NotificationManager` | 系统通知 |
| `AppConfig` | 用户偏好（含 API Key 通过 SecureStorage 加密） |
| `SecureStorage` | ChaChaPoly 文件加密，避免 Keychain 授权弹窗 |

## 同步流程

1. **拉取**（云端 → 本地）
   - 按标题匹配
   - 若云端已完成而本地未完成：标记本地完成
   - 若云端有而本地无且未完成：创建本地
2. **重新拉取本地**（获取拉取后的最新状态）
3. **推送**（本地 → 云端）
   - 仅完成状态变化：调用 `/todos/{id}/complete|incomplete` 端点
   - 其他字段变化：`updateTodo` + 单独更新完成状态

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
- API Key：同上
- 冲突策略：设置 → 同步策略
- 设备映射：设置 → 设备映射

## 权限

应用首次启动会请求：

- 提醒事项（Reminders / EventKit）
- 通知（用于同步完成/失败提示）

## 开发

```bash
open InkSync.xcodeproj
```

最低支持：macOS 13.0

## 安全

- API Key 使用 ChaChaPoly 对称加密存储于 `~/Library/Application Support/InkSync/secrets.dat`
- 加密密钥通过 HKDF 从 Bundle ID 派生
- 不使用 Keychain，避免未签名应用的反复授权弹窗
- TextField 输入，不触发系统密码管理器联想
