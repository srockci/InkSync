import Foundation

enum TodoSource: String, Codable, Equatable {
    case local
    case remote
}

struct TodoItem: Identifiable, Equatable {
    let id: String
    var title: String
    var notes: String?
    var isCompleted: Bool
    var dueDate: Date?
    var dueTime: Date?
    var priority: Int
    let listId: String
    let listName: String
    var lastModified: Date
    let source: TodoSource
}
