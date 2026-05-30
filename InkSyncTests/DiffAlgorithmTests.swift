import XCTest
@testable import InkSync

final class DiffAlgorithmTests: XCTestCase {
    func testEmptyLists() {
        let diff = calculateDiff(local: [], remote: [])
        XCTAssertTrue(diff.toPush.isEmpty)
        XCTAssertTrue(diff.toPull.isEmpty)
        XCTAssertTrue(diff.conflicts.isEmpty)
    }

    func testLocalOnly() {
        let local = [
            TodoItem(
                id: "1",
                title: "Test",
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
        ]
        let diff = calculateDiff(local: local, remote: [])
        XCTAssertEqual(diff.toPush.count, 1)
        XCTAssertEqual(diff.toPush[0].id, "1")
        XCTAssertTrue(diff.toPull.isEmpty)
    }

    func testRemoteOnly() {
        let remote = [
            TodoItem(
                id: "1",
                title: "Test",
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
        ]
        let diff = calculateDiff(local: [], remote: remote)
        XCTAssertTrue(diff.toPush.isEmpty)
        XCTAssertEqual(diff.toPull.count, 1)
        XCTAssertEqual(diff.toPull[0].id, "1")
    }

    func testBothSameNoChange() {
        let now = Date()
        let local = TodoItem(
            id: "1",
            title: "Test",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: now,
            source: .local
        )
        let remote = TodoItem(
            id: "1",
            title: "Test",
            notes: nil,
            isCompleted: false,
            dueDate: nil,
            dueTime: nil,
            priority: 0,
            listId: "list1",
            listName: "Test",
            lastModified: now,
            source: .remote
        )
        let diff = calculateDiff(local: [local], remote: [remote])
        XCTAssertTrue(diff.toPush.isEmpty)
        XCTAssertTrue(diff.toPull.isEmpty)
    }

    func testLocalNewerPushes() {
        let old = Date().addingTimeInterval(-100)
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
            lastModified: old,
            source: .remote
        )
        let diff = calculateDiff(local: [local], remote: [remote])
        XCTAssertEqual(diff.toPush.count, 1)
        XCTAssertEqual(diff.toPush[0].title, "Local")
        XCTAssertTrue(diff.toPull.isEmpty)
    }

    func testRemoteNewerPulls() {
        let old = Date().addingTimeInterval(-100)
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
            lastModified: old,
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
        let diff = calculateDiff(local: [local], remote: [remote])
        XCTAssertTrue(diff.toPush.isEmpty)
        XCTAssertEqual(diff.toPull.count, 1)
        XCTAssertEqual(diff.toPull[0].title, "Remote")
    }

    func testHasChanges() {
        let local = TodoItem(
            id: "1",
            title: "Test",
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
        let diff = calculateDiff(local: [local], remote: [])
        XCTAssertTrue(diff.hasChanges)
        XCTAssertEqual(diff.totalChanges, 1)
    }

    func testNoChanges() {
        let diff = calculateDiff(local: [], remote: [])
        XCTAssertFalse(diff.hasChanges)
        XCTAssertEqual(diff.totalChanges, 0)
    }
}