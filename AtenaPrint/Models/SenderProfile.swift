import AtenaCore
import Foundation
import SwiftData

@Model
final class SenderProfile {
    /// Stable identifier referenced from the saved layout settings.
    var uuid: UUID = UUID()
    /// User-facing label such as "自宅" or "仕事".
    var label: String = ""
    var name: String = ""
    var jointNames: [String] = []
    var postalCode: String = ""
    var address1: String = ""
    var address2: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(label: String, sortOrder: Int) {
        self.label = label
        self.sortOrder = sortOrder
    }

    var content: SenderContent {
        SenderContent(name: name, jointNames: jointNames, postalCode: postalCode, address1: address1, address2: address2)
    }
}
