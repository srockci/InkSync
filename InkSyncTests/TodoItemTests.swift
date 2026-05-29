import XCTest
@testable import InkSync

final class TodoItemTests: XCTestCase {
    func testTodoItemEquality() {
        let now = Date()
        let itemA = TodoItem(
            id: "1",
            title: "Buy milk",
            notes: "2%",
            isCompleted: false,
            dueDate: now,
            dueTime: nil,
            priority: 0,
            listId: "list-1",
            listName: "Personal",
            lastModified: now,
            source: .local
        )

        let itemB = TodoItem(
            id: "1",
            title: "Buy milk",
            notes: "2%",
            isCompleted: false,
            dueDate: now,
            dueTime: nil,
            priority: 0,
            listId: "list-1",
            listName: "Personal",
            lastModified: now,
            source: .local
        )

        XCTAssertEqual(itemA, itemB)
    }

    func testTodoSourceRawValues() {
        XCTAssertEqual(TodoSource.local.rawValue, "local")
        XCTAssertEqual(TodoSource.remote.rawValue, "remote")
    }
}
