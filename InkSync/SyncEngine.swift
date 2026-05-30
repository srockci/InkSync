import Foundation
import Combine

@MainActor
final class SyncEngine: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var nextSyncTime: Date?
    @Published var currentSyncDevice: Device?
    @Published var syncProgress: String = ""

    private let eventKitManager: EventKitManager
    private let apiClient: APIClient
    private let mappingManager: MappingManager
    private let notificationManager: NotificationManager
    private let syncLogStore: SyncLogStore

    private var syncTimer: Timer?
    private let pollingInterval: TimeInterval = 300

    private var conflictStrategy: ConflictStrategy {
        let rawValue = UserDefaults.standard.string(forKey: "conflictStrategy") ?? ConflictStrategy.timestampPriority.rawValue
        return ConflictStrategy(rawValue: rawValue) ?? .timestampPriority
    }

    init(
        eventKitManager: EventKitManager,
        apiClient: APIClient,
        mappingManager: MappingManager,
        notificationManager: NotificationManager = .shared,
        syncLogStore: SyncLogStore = SyncLogStore()
    ) {
        self.eventKitManager = eventKitManager
        self.apiClient = apiClient
        self.mappingManager = mappingManager
        self.notificationManager = notificationManager
        self.syncLogStore = syncLogStore

        lastSyncTime = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date
        updateNextSyncTime()
    }

    deinit {
        syncTimer?.invalidate()
    }

    func startPolling() {
        stopPolling()
        syncTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
    }

    func stopPolling() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncProgress = "开始同步..."

        for device in mappingManager.devices {
            if !device.isOnline {
                syncProgress = "\(device.alias) 离线，跳过"
                continue
            }

            currentSyncDevice = device
            syncProgress = "同步 \(device.alias)..."

            do {
                try await sync(device: device)
            } catch {
                handleError(error, device: device)
            }
        }

        currentSyncDevice = nil
        lastSyncTime = Date()
        UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
        updateNextSyncTime()

        isSyncing = false
        syncProgress = "同步完成"
    }

    func sync(device: Device) async throws {
        let listIds = mappingManager.config.lists(for: device.id)
        guard !listIds.isEmpty else {
            let record = SyncRecord(
                id: UUID(),
                timestamp: Date(),
                deviceId: device.id,
                type: .noChange,
                details: "该设备未分配任何列表",
                itemCount: 0
            )
            syncLogStore.addRecord(record)
            return
        }

        let localReminders = await eventKitManager.fetchReminders(from: listIds)
        let calendarNames = Dictionary(
            uniqueKeysWithValues: eventKitManager.fetchCalendars().map { ($0.calendarIdentifier, $0.title) }
        )
        let localTodos = localReminders.map { reminder -> TodoItem in
            let listId = reminder.calendar.calendarIdentifier
            let listName = calendarNames[listId] ?? reminder.calendar.title
            return reminder.toTodoItem(listId: listId, listName: listName)
        }

        syncProgress = "获取 \(device.alias) 远程数据..."
        let remoteTodos = try await apiClient.fetchTodos(deviceId: device.id, status: nil)

        syncProgress = "计算差异..."
        let diff = calculateDiff(local: localTodos, remote: remoteTodos)

        if !diff.hasChanges {
            let record = SyncRecord(
                id: UUID(),
                timestamp: Date(),
                deviceId: device.id,
                type: .noChange,
                details: "无变更",
                itemCount: 0
            )
            syncLogStore.addRecord(record)
            notificationManager.notifySyncCompleted(device: device, itemCount: 0)
            return
        }

        let conflicts = detectConflicts(local: localTodos, remote: remoteTodos, lastSyncTime: lastSyncTime)
        let resolved = resolveConflicts(conflicts, strategy: conflictStrategy)

        syncProgress = "推送本地变更到 \(device.alias)..."
        var pushedCount = 0
        for todo in diff.toPush {
            do {
                if localTodos.contains(where: { $0.id == todo.id }) {
                    _ = try await apiClient.updateTodo(todo)
                } else {
                    _ = try await apiClient.createTodo(todo, deviceId: device.id)
                }
                pushedCount += 1
            } catch {
                print("推送失败: \(error)")
            }
        }

        syncProgress = "拉取远程变更到 \(device.alias)..."
        var pulledCount = 0
        for todo in diff.toPull {
            do {
                if resolved.contains(where: { $0.id == todo.id }) {
                    try await eventKitManager.saveTodo(todo)
                    pulledCount += 1
                }
            } catch {
                print("拉取失败: \(error)")
            }
        }

        for todo in resolved {
            if !diff.toPull.contains(where: { $0.id == todo.id }) {
                try? await eventKitManager.saveTodo(todo)
            }
        }

        let totalChanges = pushedCount + pulledCount + resolved.count
        let recordType: SyncRecordType = conflicts.isEmpty ? (pushedCount > 0 ? .push : .pull)
            : (conflicts.isEmpty == false ? .conflict : .noChange)

        let record = SyncRecord(
            id: UUID(),
            timestamp: Date(),
            deviceId: device.id,
            type: recordType,
            details: buildDetails(pushed: pushedCount, pulled: pulledCount, resolved: conflicts.count),
            itemCount: totalChanges
        )
        syncLogStore.addRecord(record)

        if !conflicts.isEmpty {
            notificationManager.notifyConflictResolved(device: device, count: resolved.count)
        } else {
            notificationManager.notifySyncCompleted(device: device, itemCount: totalChanges)
        }
    }

    private func handleError(_ error: Error, device: Device) {
        let record = SyncRecord(
            id: UUID(),
            timestamp: Date(),
            deviceId: device.id,
            type: .failure,
            details: error.localizedDescription,
            itemCount: 0
        )
        syncLogStore.addRecord(record)
        notificationManager.notifySyncFailed(device: device, error: error)
    }

    private func updateNextSyncTime() {
        nextSyncTime = Date().addingTimeInterval(pollingInterval)
    }

    private func buildDetails(pushed: Int, pulled: Int, resolved: Int) -> String {
        var parts: [String] = []
        if pushed > 0 { parts.append("推送\(pushed)") }
        if pulled > 0 { parts.append("拉取\(pulled)") }
        if resolved > 0 { parts.append("解决冲突\(resolved)") }
        return parts.isEmpty ? "无变更" : parts.joined(separator: ", ")
    }
}