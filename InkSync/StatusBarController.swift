import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState = AppState()
    private let eventKitManager: EventKitManager

    var currentStatus: SyncStatus = .idle {
        didSet {
            appState.syncStatus = currentStatus
            updateIcon()
        }
    }

    init(eventKitManager: EventKitManager) {
        self.eventKitManager = eventKitManager
        super.init()
        setupStatusItem()
        setupPopover()
        updateIcon()
        setupRemindersMonitoring()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.delegate = self

        let rootView = MenuPopoverView(
            appState: appState,
            eventKitManager: eventKitManager,
            onSyncNow: { [weak self] in
                self?.handleSyncNow()
            },
            onViewChanges: {
                print("打开同步记录窗口")
            },
            onOpenSettings: {
                print("打开设置窗口")
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.contentViewController = NSHostingController(rootView: rootView)
        self.popover = popover
    }

    private func setupRemindersMonitoring() {
        eventKitManager.startMonitoringChanges {
            print("Reminders 数据已变更")
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func handleSyncNow() {
        print("立即同步")
        currentStatus = .syncing

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            currentStatus = .idle
        }
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        stopRotationAnimation()

        let symbolName: String
        let tintColor: NSColor

        switch currentStatus {
        case .idle:
            symbolName = "hexagon"
            tintColor = .secondaryLabelColor
        case .syncing:
            symbolName = "hexagon.fill"
            tintColor = .controlAccentColor
        case .failed:
            symbolName = "exclamationmark.triangle.fill"
            tintColor = .systemYellow
        case .conflict:
            symbolName = "circle.badge.plus"
            tintColor = .controlAccentColor
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "InkSync")?
            .withSymbolConfiguration(configuration)

        button.image = image
        button.image?.isTemplate = true
        button.contentTintColor = tintColor

        if currentStatus == .syncing {
            startRotationAnimation(on: button)
        }
    }

    private func startRotationAnimation(on button: NSStatusBarButton) {
        button.wantsLayer = true

        guard let layer = button.layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = -Double.pi * 2
        animation.duration = 1.0
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: "rotation")
    }

    private func stopRotationAnimation() {
        statusItem?.button?.layer?.removeAnimation(forKey: "rotation")
    }

    func popoverDidClose(_ notification: Notification) {
        stopRotationAnimation()
        if currentStatus == .syncing {
            updateIcon()
        }
    }
}
