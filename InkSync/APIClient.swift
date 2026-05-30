import Foundation

protocol APIClient {
    func fetchDevices() async throws -> [Device]
}

final class MockAPIClient: APIClient {
    func fetchDevices() async throws -> [Device] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return [
            Device(
                id: "dev1",
                alias: "书房墨水屏",
                lastSyncTime: Date().addingTimeInterval(-120),
                isOnline: true,
                syncedLists: []
            ),
            Device(
                id: "dev2",
                alias: "办公室墨水屏",
                lastSyncTime: Date().addingTimeInterval(-300),
                isOnline: true,
                syncedLists: []
            )
        ]
    }
}