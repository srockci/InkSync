import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {
        checkAuthorization()
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func notifySyncCompleted(device: Device, itemCount: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "同步完成"
        content.body = "\(device.alias) 同步了 \(itemCount) 项"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync_completed_\(device.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifySyncFailed(device: Device, error: Error) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "同步失败"
        content.body = "\(device.alias): \(error.localizedDescription)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sync_failed_\(device.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyConflictResolved(device: Device, count: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "冲突已解决"
        content.body = "\(device.alias) 解决了 \(count) 个冲突"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "conflict_\(device.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}