import SwiftUI

@main
struct InkSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let eventKitManager = EventKitManager()
    let apiClient = MockAPIClient()
    lazy var mappingManager = MappingManager(eventKitManager: eventKitManager, apiClient: apiClient)
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            eventKitManager: eventKitManager,
            mappingManager: mappingManager
        )

        Task {
            _ = try? await eventKitManager.requestAccess()
            mappingManager.loadAvailableLists()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventKitManager.refreshAuthorizationStatus()
        }
    }
}
