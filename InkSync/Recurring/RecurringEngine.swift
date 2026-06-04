import Foundation
import EventKit

@MainActor
final class RecurringEngine: ObservableObject {
    @Published private(set) var rules: [RecurringReminder] = []
    @Published private(set) var todayGeneratedCount: Int = 0
    @Published private(set) var lastTriggerTime: Date?

    private let store: RecurringReminderStore
    private let logger: RecurringGenerationLogger
    private let scheduler: RecurrenceScheduler
    private let eventKitManager: EventKitManager
    private let mappingManager: MappingManager
    private let notificationManager: NotificationManager

    private var timer: Timer?
    private let checkInterval: TimeInterval = 15
    private let graceWindowMinutes: Int = 5

    init(
        store: RecurringReminderStore = .shared,
        logger: RecurringGenerationLogger = .shared,
        scheduler: RecurrenceScheduler = RecurrenceScheduler(),
        eventKitManager: EventKitManager,
        mappingManager: MappingManager,
        notificationManager: NotificationManager = .shared
    ) {
        self.store = store
        self.logger = logger
        self.scheduler = scheduler
        self.eventKitManager = eventKitManager
        self.mappingManager = mappingManager
        self.notificationManager = notificationManager
        self.rules = store.loadAll()
        updateTodayCount()
    }

    func mappingManagerForUI() -> MappingManager { mappingManager }

    func start() {
        stop()
        rebuildSchedule()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndTrigger()
            }
        }
        checkAndTrigger()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reload() {
        rules = store.loadAll()
        rebuildSchedule()
        updateTodayCount()
    }

    func addRule(_ rule: RecurringReminder) {
        var updated = rule
        updated.nextScheduledAt = scheduler.nextTriggerDate(for: updated)
        store.add(updated)
        rules = store.loadAll()
        updateTodayCount()
    }

    func updateRule(_ rule: RecurringReminder) {
        var updated = rule
        updated.updatedAt = Date()
        updated.nextScheduledAt = scheduler.nextTriggerDate(for: updated)
        store.update(updated)
        rules = store.loadAll()
        updateTodayCount()
    }

    func deleteRule(_ id: UUID) {
        store.delete(id)
        rules = store.loadAll()
        updateTodayCount()
    }

    func deleteRules(_ ids: [UUID]) {
        store.deleteMany(ids)
        rules = store.loadAll()
        updateTodayCount()
    }

    func setEnabled(_ id: UUID, enabled: Bool) {
        store.setEnabled(id, enabled: enabled)
        rules = store.loadAll()
    }

    private func rebuildSchedule() {
        let rebuilt = scheduler.rebuildSchedule(for: rules)
        for rule in rebuilt {
            store.update(rule)
        }
        rules = store.loadAll()
    }

    private func checkAndTrigger() {
        let now = Date()
        let graceStart = now.addingTimeInterval(-TimeInterval(graceWindowMinutes * 60))
        let tolerance: TimeInterval = 1.0

        for rule in rules where rule.isEnabled {
            guard let next = rule.nextScheduledAt else { continue }
            if next <= now.addingTimeInterval(tolerance) && next >= graceStart {
                trigger(rule: rule)
            } else if next < graceStart {
                let updated = skipMissed(rule: rule)
                store.update(updated)
            }
        }

        rebuildSchedule()
        lastTriggerTime = now
        updateTodayCount()
    }

    private func trigger(rule: RecurringReminder) {
        let listIds = mappingManager.config.lists(for: deviceIdForRule(rule))
        let targetList = listIds.first

        let tags = rule.advancedOptions.tags
        let taggedTitle = tags.isEmpty ? rule.title : rule.title + " " + tags.map { "#\($0)" }.joined(separator: " ")

        var log = GenerationLog(
            ruleId: rule.id,
            ruleTitle: rule.title,
            scheduledTime: rule.nextScheduledAt ?? Date(),
            actualTime: Date()
        )

        Task { @MainActor in
            var success = false
            var createdItemId: String?
            var errorMessage: String?

            if let targetList {
                do {
                    let reminder = try await eventKitManager.createReminder(
                        title: taggedTitle,
                        notes: rule.notes,
                        listId: targetList,
                        dueDate: rule.nextScheduledAt
                    )
                    if rule.advancedOptions.autoComplete {
                        try? await eventKitManager.setCompleted(true, forReminderId: reminder.id)
                    }
                    createdItemId = reminder.id
                    success = true
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = "未配置同步列表"
            }

            log.success = success
            log.createdItemId = createdItemId
            log.errorMessage = errorMessage
            logger.append(log)

            var updated = rule
            updated.lastGeneratedAt = Date()
            updated.nextScheduledAt = scheduler.nextTriggerDate(for: updated)
            store.update(updated)
            rules = store.loadAll()
            updateTodayCount()

            sendNotification(for: log)
        }
    }

    private func deviceIdForRule(_ rule: RecurringReminder) -> String {
        mappingManager.devices.first?.id ?? ""
    }

    private func skipMissed(rule: RecurringReminder) -> RecurringReminder {
        var updated = rule
        updated.nextScheduledAt = scheduler.nextTriggerDate(for: updated)
        return updated
    }

    private func sendNotification(for log: GenerationLog) {
        if log.success {
            notificationManager.notifyRecurringSuccess(title: log.ruleTitle, targets: 1)
        } else {
            notificationManager.notifyRecurringFailure(title: log.ruleTitle)
        }
    }

    private func updateTodayCount() {
        let logs = logger.loadAll()
        let calendar = Calendar.current
        todayGeneratedCount = logs.filter { calendar.isDateInToday($0.actualTime) }.count
    }
}