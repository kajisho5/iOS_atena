import Foundation
import SwiftData

@Model
final class RecipientGroup {
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var recipients: [Recipient] = []

    @Relationship(deleteRule: .nullify, inverse: \PrintRecord.group)
    var printRecords: [PrintRecord] = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
