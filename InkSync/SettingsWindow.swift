import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var appConfig: AppConfig
    @ObservedObject var mappingManager: MappingManager
    @ObservedObject var syncEngine: SyncEngine
    let apiClient: APIClient

    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var isVerifying = false

    enum ConnectionStatus {
        case idle, success, failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    apiConfigSection
                    deviceMappingSection
                    syncRulesSection
                    notificationPrefsSection
                    actionButtons
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
            Text("设置")
                .font(.title2.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var apiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("云端账户", systemImage: "link")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("API 地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://cloud.zectrix.com/open/v1", text: $appConfig.apiURL)
                    .textFieldStyle(.roundedBorder)

                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("输入 API Key", text: $appConfig.apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("验证连接") {
                        verifyConnection()
                    }
                    .disabled(isVerifying || appConfig.apiKey.isEmpty)

                    if isVerifying {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    switch connectionStatus {
                    case .idle:
                        EmptyView()
                    case .success:
                        Label("正常", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failed(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var deviceMappingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("设备与列表映射", systemImage: "rectangle.connected.to.line.below")
                .font(.headline)

            if mappingManager.devices.isEmpty {
                HStack {
                    ProgressView()
                    Text("加载设备中...")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                ForEach(mappingManager.devices) { device in
                    DeviceMappingRow(
                        device: device,
                        assignedLists: mappingManager.config.lists(for: device.id),
                        availableLists: mappingManager.availableLists(for: device.id),
                        onAssign: { mappingManager.assignList($0, to: device.id) },
                        onUnassign: { mappingManager.unassignList($0, from: device.id) }
                    )
                }

                let unassigned = mappingManager.config.unassignedLists(
                    allListIds: mappingManager.availableLists.map { $0.calendarIdentifier }
                )
                if !unassigned.isEmpty {
                    let unassignedNames = unassigned.compactMap { id in
                        mappingManager.availableLists.first { $0.calendarIdentifier == id }?.title
                    }.joined(separator: ", ")
                    Text("未分配列表: \(unassignedNames)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var syncRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("同步规则", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("冲突解决策略")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                    HStack {
                        RadioButton(
                            title: strategy.displayName,
                            isSelected: appConfig.conflictStrategy == strategy
                        ) {
                            appConfig.conflictStrategy = strategy
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var notificationPrefsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("通知偏好", systemImage: "bell")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("同步成功通知", isOn: $appConfig.notifyOnSuccess)
                Toggle("同步失败通知", isOn: $appConfig.notifyOnFailure)
                Toggle("冲突解决通知", isOn: $appConfig.notifyOnConflict)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var actionButtons: some View {
        HStack {
            Button("保存并立即生效") {
                saveAndApply()
            }
            .buttonStyle(.borderedProminent)

            Button("重置同步记录") {
                appConfig.resetSyncRecords()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private func verifyConnection() {
        isVerifying = true
        connectionStatus = .idle

        Task {
            do {
                _ = try await apiClient.fetchDevices()
                await MainActor.run {
                    connectionStatus = .success
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failed("连接失败")
                    isVerifying = false
                }
            }
        }
    }

    private func saveAndApply() {
        mappingManager.saveConfig()
        syncEngine.stopPolling()
        syncEngine.startPolling()
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(title)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDeviceMappingRow: View {
    let device: Device
    let assignedLists: [String]
    let availableLists: [EKCalendar]
    let onAssign: (String) -> Void
    let onUnassign: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(device.alias)
                    .font(.subheadline.weight(.medium))

                Spacer()

                if device.isOnline {
                    Text("在线")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("离线")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Text("同步:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)

                FlowLayout(spacing: 4) {
                    ForEach(assignedLists, id: \.self) { listId in
                        if let list = availableLists.first(where: { $0.calendarIdentifier == listId }) {
                            HStack(spacing: 4) {
                                Text(list.title)
                                    .font(.caption)
                                Button(action: { onUnassign(listId) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                        }
                    }

                    Menu {
                        ForEach(availableLists, id: \.calendarIdentifier) { list in
                            Button(list.title) {
                                onAssign(list.calendarIdentifier)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                            Text("添加")
                        }
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init(
        appConfig: AppConfig,
        mappingManager: MappingManager,
        syncEngine: SyncEngine,
        apiClient: APIClient
    ) {
        let settingsView = SettingsView(
            appConfig: appConfig,
            mappingManager: mappingManager,
            syncEngine: syncEngine,
            apiClient: apiClient
        )

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()

        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}