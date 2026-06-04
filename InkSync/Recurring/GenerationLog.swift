import Foundation

struct GenerationLog: Codable, Identifiable {
    let id: UUID
    let ruleId: UUID
    let ruleTitle: String
    let scheduledTime: Date
    let actualTime: Date
    var success: Bool
    var createdItemId: String?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        ruleId: UUID,
        ruleTitle: String,
        scheduledTime: Date,
        actualTime: Date = Date(),
        success: Bool = false,
        createdItemId: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.ruleId = ruleId
        self.ruleTitle = ruleTitle
        self.scheduledTime = scheduledTime
        self.actualTime = actualTime
        self.success = success
        self.createdItemId = createdItemId
        self.errorMessage = errorMessage
    }
}