import XCTest
@testable import InkSync

final class ConflictResolutionTests: XCTestCase {
    func testTimestampPriorityLocalNewer() {
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100),
            source: .remote
        )

        let winner = resolveConflicts([(local: local, remote: remote)], strategy: .timestampPriority)
        XCTAssertEqual(winner.count, 1)
        XCTAssertEqual(winner[0].title, "Local")
    }

    func testTimestampPriorityRemoteNewer() {
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100),
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .remote
        )

        let winner = resolveConflicts([(local: local, remote: remote)], strategy: .timestampPriority)
        XCTAssertEqual(winner.count, 1)
        XCTAssertEqual(winner[0].title, "Remote")
    }

    func testApplePriorityAlwaysLocal() {
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100),
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .remote
        )

        let winner = resolveConflicts([(local: local, remote: remote)], strategy: .applePriority)
        XCTAssertEqual(winner.count, 1)
        XCTAssertEqual(winner[0].title, "Local")
    }

    func testDevicePriorityAlwaysRemote() {
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100),
            source: .remote
        )

        let winner = resolveConflicts([(local: local, remote: remote)], strategy: .devicePriority)
        XCTAssertEqual(winner.count, 1)
        XCTAssertEqual(winner[0].title, "Remote")
    }

    func testDetectConflictsBothModifiedAfterSync() {
        let lastSync = Date().addingTimeInterval(-1000)
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(), // after lastSync
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(), // after lastSync
            source: .remote
        )

        let conflicts = detectConflicts(local: [local], remote: [remote], lastSyncTime: lastSync)
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].local.id, "1")
        XCTAssertEqual(conflicts[0].remote.id, "1")
    }

    func testDetectConflictsNoConflictIfNotModifiedAfterSync() {
        let lastSync = Date()
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100), // before lastSync
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date().addingTimeInterval(-100), // before lastSync
            source: .remote
        )

        let conflicts = detectConflicts(local: [local], remote: [remote], lastSyncTime: lastSync)
        XCTAssertTrue(conflicts.isEmpty)
    }

    func testDetectConflictsNoConflictIfNoLastSync() {
        let local = TodoItem(
            id: "1",
            title: "Local",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Remote",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: Date(),
            source: .remote
        )

        let conflicts = detectConflicts(local: [local], remote: [remote], lastSyncTime: nil)
        XCTAssertTrue(conflicts.isEmpty)
    }
}