import XCTest
@testable import InkSync

final class SyncLogStoreTests: XCTestCase {
    private var store: SyncLogStore!
    private var testLogPath: URL!

    override func setUp() {
        super.setUp()
        store = SyncLogStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testAddRecord() {
        let record = SyncRecord(
            id: UUID(),
            timestamp: Date(),
            deviceId: "dev1",
            type: .push,
            details: "Test push",
            itemCount: 3
        )

        store.addRecord(record)

        let records = store.fetchAllRecords()
        XCTAssertFalse(records.isEmpty)
        XCTAssertEqual(records[0].deviceId, "dev1")
        XCTAssertEqual(records[0].type, .push)
        XCTAssertEqual(records[0].itemCount, 3)
    }

    func testFetchTodayRecords() {
        let today = SyncRecord(
            id: UUID(),
            timestamp: Date(),
            deviceId: "dev1",
            type: .noChange,
            details: "Today",
            itemCount: 0
        )
        let yesterday = SyncRecord(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-86400),
            deviceId: "dev1",
            type: .noChange,
            details: "Yesterday",
            itemCount: 0
        )

        store.addRecord(today)
        store.addRecord(yesterday)

        let todayRecords = store.fetchTodayRecords()
        XCTAssertEqual(todayRecords.count, 1)
        XCTAssertEqual(todayRecords[0].details, "Today")
    }

    func testFetchRecordsDateRange() {
        let now = Date()
        let record = SyncRecord(
            id: UUID(),
            timestamp: now,
            deviceId: "dev1",
            type: .push,
            details: "In range",
            itemCount: 1
        )
        let oldRecord = SyncRecord(
            id: UUID(),
            timestamp: now.addingTimeInterval(-86400 * 10),
            deviceId: "dev1",
            type: .push,
            details: "Too old",
            itemCount: 1
        )

        store.addRecord(record)
        store.addRecord(oldRecord)

        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let rangeRecords = store.fetchRecords(from: startOfDay, to: endOfDay)
        XCTAssertEqual(rangeRecords.count, 1)
        XCTAssertEqual(rangeRecords[0].details, "In range")
    }

    func testExportToCSV() {
        let record = SyncRecord(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 0),
            deviceId: "dev1",
            type: .push,
            details: "Test export",
            itemCount: 5
        )
        store.addRecord(record)

        let csvURL = store.exportToCSV()
        XCTAssertNotNil(csvURL)

        if let url = csvURL {
            let fileContents = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertNotNil(fileContents)
            XCTAssertTrue(fileContents!.contains("dev1"))
            XCTAssertTrue(fileContents!.contains("push"))
            XCTAssertTrue(fileContents!.contains("Test export"))
            XCTAssertTrue(fileContents!.contains("5"))
        }
    }
}