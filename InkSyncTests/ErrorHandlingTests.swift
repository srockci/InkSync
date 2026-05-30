import XCTest
@testable import InkSync

final class ErrorHandlingTests: XCTestCase {
    func testAPIErrorNetworkError() {
        let error = APIError.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertEqual(error.localizedDescription, "网络连接失败")
    }

    func testAPIErrorInvalidResponse() {
        let error = APIError.invalidResponse
        XCTAssertEqual(error.localizedDescription, "服务器响应无效")
    }

    func testAPIErrorUnauthorized() {
        let error = APIError.unauthorized
        XCTAssertEqual(error.localizedDescription, "API Key 无效或已过期")
    }

    func testAPIErrorTimeout() {
        let error = APIError.timeout
        XCTAssertEqual(error.localizedDescription, "请求超时")
    }

    func testMockAPIClientReturnsDevices() async {
        let client = MockAPIClient()
        let devices = try? await client.fetchDevices()
        XCTAssertNotNil(devices)
        XCTAssertEqual(devices?.count, 2)
    }

    func testMockAPIClientFetchTodosReturnsEmpty() async {
        let client = MockAPIClient()
        let todos = try? await client.fetchTodos(deviceId: "dev1", status: nil)
        XCTAssertNotNil(todos)
        XCTAssertTrue(todos!.isEmpty)
    }

    func testMockAPIClientCreateAndUpdateTodo() async {
        let client = MockAPIClient()
        let todo = TodoItem(
            id: "test-1",
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

        let created = try? await client.createTodo(todo, deviceId: "dev1")
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.id, "test-1")

        var updated = created!
        updated.title = "Updated"
        let result = try? await client.updateTodo(updated)
        XCTAssertNotNil(result)
    }
}

enum APIError: LocalizedError {
    case networkError(underlying: Error)
    case invalidResponse
    case unauthorized
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "网络连接失败"
        case .invalidResponse:
            return "服务器响应无效"
        case .unauthorized:
            return "API Key 无效或已过期"
        case .timeout:
            return "请求超时"
        case .unknown:
            return "未知错误"
        }
    }
}