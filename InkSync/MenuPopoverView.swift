import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var eventKitManager: EventKitManager
    @ObservedObject var mappingManager: MappingManager
    var onSyncNow: () -> Void
    var onViewChanges: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if eventKitManager.isAccessDenied {
                permissionDeniedBanner
                Divider()
            }

            statusSection
            Divider()
            deviceSection
            Divider()
            actionButtons
            Divider()
            footer
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $mappingManager.showSettings) {
            MappingConfigView(mappingManager: mappingManager)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "hexagon.fill")
                .foregroundStyle(.secondary)
            Text("InkSync")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("状态: \(appState.statusDescription)")
                .font(.subheadline)

            if let nextSync = appState.nextSyncTime {
                Text("下次同步: \(nextSyncTimeText(nextSync))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var permissionDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("无法访问提醒事项")
                    .font(.subheadline.weight(.medium))
            }

            Text("InkSync 需要访问「提醒事项」才能同步待办。请在系统设置中开启权限。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("打开系统设置") {
                SystemSettings.openRemindersPrivacy()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📟 设备 (\(appState.onlineDeviceCount)台在线)")
                .font(.subheadline.weight(.medium))

            ForEach(appState.devices) { device in
                DeviceRow(device: device)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onSyncNow) {
                Text("立即同步")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button(action: onViewChanges) {
                Text("查看今日变更")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Button("打开设置...", action: onOpenSettings)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

            Spacer()

            Button("退出 InkSync", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func nextSyncTimeText(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = Locale(identifier: "zh_CN")
        relativeFormatter.unitsStyle = .full

        let time = timeFormatter.string(from: date)
        let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())

        return "\(time) (\(relative))"
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("├──")
                    .foregroundStyle(.tertiary)
                    .font(.caption)

                Text(device.alias)
                    .font(.subheadline)

                if device.isOnline {
                    Text("✅")
                        .font(.caption)
                }

                Spacer()

                if let lastSync = device.lastSyncTime {
                    Text(relativeSyncText(lastSync))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                Text("│   └─ 同步列表: ")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                Text(device.syncedLists.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)
        }
    }

    private func relativeSyncText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    MenuPopoverView(
        appState: AppState(),
        eventKitManager: EventKitManager(),
        mappingManager: MappingManager(eventKitManager: EventKitManager(), apiClient: MockAPIClient()),
        onSyncNow: {},
        onViewChanges: {},
        onOpenSettings: {},
        onQuit: {}
    )
    .frame(width: 320)
}
