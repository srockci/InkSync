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
    let appConfig = AppConfig.shared
    lazy var mappingManager = MappingManager(eventKitManager: eventKitManager, apiClient: apiClient)
    lazy var syncEngine = SyncEngine(
        eventKitManager: eventKitManager,
        apiClient: apiClient,
        mappingManager: mappingManager
    )

    var statusBarController: StatusBarController?
    var settingsWindowController: SettingsWindowController?
    var onboardingWindowController: OnboardingWindowController?
    var syncLogWindowController: SyncLogWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowControllers()
        setupStatusBar()
        setupSyncEngine()
        requestPermissions()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventKitManager.refreshAuthorizationStatus()
        }
    }

    private func setupWindowControllers() {
        settingsWindowController = SettingsWindowController(
            appConfig: appConfig,
            mappingManager: mappingManager,
            syncEngine: syncEngine,
            apiClient: apiClient
        )

        onboardingWindowController = OnboardingWindowController(
            appConfig: appConfig,
            mappingManager: mappingManager,
            apiClient: apiClient
        ) { [weak self] in
            self?.onboardingWindowController?.window?.close()
            self?.onboardingWindowController = nil
        }

        syncLogWindowController = SyncLogWindowController()
    }

    private func setupStatusBar() {
        statusBarController = StatusBarController(
            eventKitManager: eventKitManager,
            mappingManager: mappingManager,
            syncEngine: syncEngine,
            onOpenSettings: { [weak self] in
                self?.showSettings()
            },
            onViewSyncLog: { [weak self] in
                self?.showSyncLog()
            }
        )

        if !appConfig.hasCompletedOnboarding {
            onboardingWindowController?.showWindow()
        }
    }

    private func setupSyncEngine() {
        syncEngine.startPolling()
    }

    private func requestPermissions() {
        Task {
            _ = try? await eventKitManager.requestAccess()
            mappingManager.loadAvailableLists()

            _ = await NotificationManager.shared.requestAuthorization()
        }
    }

    func showSettings() {
        settingsWindowController?.showWindow()
    }

    func showSyncLog() {
        syncLogWindowController?.showWindow()
    }

    func showOnboarding() {
        onboardingWindowController?.showWindow()
    }
}