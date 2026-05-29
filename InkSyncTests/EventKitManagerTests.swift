import EventKit
import XCTest
@testable import InkSync

@MainActor
final class EventKitManagerTests: XCTestCase {
    private var manager: EventKitManager!

    override func setUp() async throws {
        manager = EventKitManager()
    }

    override func tearDown() async throws {
        manager.stopMonitoringChanges()
        manager = nil
    }

    func testAuthorizationStatusIsRefreshedOnInit() {
        let expected = EKEventStore.authorizationStatus(for: .reminder)
        XCTAssertEqual(manager.authorizationStatus, expected)
    }

    func testFetchCalendarsRequiresAuthorization() {
        manager.refreshAuthorizationStatus()
        let calendars = manager.fetchCalendars()

        if manager.isAuthorized {
            XCTAssertFalse(calendars.isEmpty)
        } else {
            XCTAssertTrue(calendars.isEmpty)
        }
    }

    func testReminderCRUDAndToggleCompletion() async throws {
        guard try await manager.requestAccess() else {
            throw XCTSkip("Reminders access not granted")
        }

        let calendars = manager.fetchCalendars()
        guard let calendar = calendars.first else {
            XCTFail("No reminder calendars available")
            return
        }

        let uniqueTitle = "InkSync Test \(UUID().uuidString)"
        let dueDate = Date().addingTimeInterval(3600)

        let created = try manager.createReminder(
            title: uniqueTitle,
            notes: "integration test",
            dueDate: dueDate,
            calendarId: calendar.calendarIdentifier
        )

        XCTAssertEqual(created.title, uniqueTitle)
        XCTAssertEqual(created.notes, "integration test")
        XCTAssertFalse(created.isCompleted)

        let calendarId = calendar.calendarIdentifier
        let fetched = await manager.fetchReminders(from: [calendarId])
        XCTAssertTrue(fetched.contains { $0.calendarItemIdentifier == created.calendarItemIdentifier })

        created.notes = "updated notes"
        try manager.updateReminder(created)

        let refreshed = await manager.fetchReminders(from: [calendarId])
        let updated = refreshed.first { $0.calendarItemIdentifier == created.calendarItemIdentifier }
        XCTAssertEqual(updated?.notes, "updated notes")

        try manager.toggleCompletion(created)
        let completed = await manager.fetchReminders(from: [calendarId])
        let toggled = completed.first { $0.calendarItemIdentifier == created.calendarItemIdentifier }
        XCTAssertEqual(toggled?.isCompleted, true)

        try manager.toggleCompletion(created)
        let reopened = await manager.fetchReminders(from: [calendarId])
        let undone = reopened.first { $0.calendarItemIdentifier == created.calendarItemIdentifier }
        XCTAssertEqual(undone?.isCompleted, false)

        try manager.deleteReminder(created)

        let afterDelete = await manager.fetchReminders(from: [calendarId])
        XCTAssertFalse(afterDelete.contains { $0.calendarItemIdentifier == created.calendarItemIdentifier })
    }

    func testFetchRemindersIncludesCompletedItems() async throws {
        guard try await manager.requestAccess() else {
            throw XCTSkip("Reminders access not granted")
        }

        guard let calendar = manager.fetchCalendars().first else {
            XCTFail("No reminder calendars available")
            return
        }

        let reminder = try manager.createReminder(
            title: "InkSync Completed \(UUID().uuidString)",
            notes: nil,
            dueDate: nil,
            calendarId: calendar.calendarIdentifier
        )
        defer { try? manager.deleteReminder(reminder) }

        try manager.toggleCompletion(reminder)

        let fetched = await manager.fetchReminders(from: [calendar.calendarIdentifier])
        let match = fetched.first { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
        XCTAssertEqual(match?.isCompleted, true)
    }

    func testTodoItemConversion() async throws {
        guard try await manager.requestAccess() else {
            throw XCTSkip("Reminders access not granted")
        }

        guard let calendar = manager.fetchCalendars().first else {
            XCTFail("No reminder calendars available")
            return
        }

        let title = "InkSync Conversion \(UUID().uuidString)"
        let reminder = try manager.createReminder(
            title: title,
            notes: "convert me",
            dueDate: Date(),
            calendarId: calendar.calendarIdentifier
        )
        defer { try? manager.deleteReminder(reminder) }

        let todo = reminder.toTodoItem(
            listId: calendar.calendarIdentifier,
            listName: calendar.title
        )

        XCTAssertEqual(todo.id, reminder.calendarItemIdentifier)
        XCTAssertEqual(todo.title, title)
        XCTAssertEqual(todo.notes, "convert me")
        XCTAssertEqual(todo.listId, calendar.calendarIdentifier)
        XCTAssertEqual(todo.listName, calendar.title)
        XCTAssertEqual(todo.source, .local)
        XCTAssertEqual(todo.priority, 0)
        XCTAssertFalse(todo.isCompleted)
    }

    func testFetchTodoItemsMapsListMetadata() async throws {
        guard try await manager.requestAccess() else {
            throw XCTSkip("Reminders access not granted")
        }

        guard let calendar = manager.fetchCalendars().first else {
            XCTFail("No reminder calendars available")
            return
        }

        let reminder = try manager.createReminder(
            title: "InkSync TodoItem \(UUID().uuidString)",
            notes: nil,
            dueDate: nil,
            calendarId: calendar.calendarIdentifier
        )
        defer { try? manager.deleteReminder(reminder) }

        let items = await manager.fetchTodoItems(from: [calendar.calendarIdentifier])
        XCTAssertTrue(items.contains { $0.id == reminder.calendarItemIdentifier })
        XCTAssertTrue(items.contains { $0.listName == calendar.title })
    }

    func testStartMonitoringChangesReceivesStoreUpdates() async throws {
        guard try await manager.requestAccess() else {
            throw XCTSkip("Reminders access not granted")
        }

        guard let calendar = manager.fetchCalendars().first else {
            XCTFail("No reminder calendars available")
            return
        }

        let expectation = expectation(description: "EKEventStoreChanged")
        var didFulfill = false
        manager.startMonitoringChanges {
            guard !didFulfill else { return }
            didFulfill = true
            expectation.fulfill()
        }

        let reminder = try manager.createReminder(
            title: "InkSync Monitor \(UUID().uuidString)",
            notes: nil,
            dueDate: nil,
            calendarId: calendar.calendarIdentifier
        )

        await fulfillment(of: [expectation], timeout: 5.0)
        try manager.deleteReminder(reminder)
    }

    func testUnauthorizedOperationsThrow() async throws {
        guard manager.isAuthorized else {
            XCTAssertThrowsError(try manager.createReminder(
                title: "blocked",
                notes: nil,
                dueDate: nil,
                calendarId: "missing"
            )) { error in
                XCTAssertEqual(error as? EventKitError, .notAuthorized)
            }
            return
        }

        XCTAssertThrowsError(try manager.createReminder(
            title: "blocked",
            notes: nil,
            dueDate: nil,
            calendarId: "missing-calendar-id"
        )) { error in
            XCTAssertEqual(error as? EventKitError, .calendarNotFound)
        }
    }
}
